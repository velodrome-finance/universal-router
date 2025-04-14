// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {InterchainAccountRouter} from '@hyperlane-updated/contracts/middleware/InterchainAccountRouter.sol';
import {TypeCasts} from '@hyperlane/core/contracts/libs/TypeCasts.sol';

import {BridgeTypes} from '../../../../contracts/libraries/BridgeTypes.sol';

import {MockHandleForwarder} from '../../mock/MockHandleForwarder.sol';
import '../../BaseForkFixture.t.sol';

contract ExecuteCrossChainTest is BaseForkFixture {
    MockInterchainAccountRouter public rootIcaRouter;
    MockInterchainAccountRouter public leafIcaRouter;

    address public constant baseUSDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function setUp() public override {
        super.setUp();

        deal(address(users.alice), 1 ether);
        rootIcaRouter = MockInterchainAccountRouter(OPTIMISM_ROUTER_ICA_ADDRESS);
        deployCodeTo(
            'MockInterchainAccountRouter.sol:MockInterchainAccountRouter',
            abi.encode(address(rootMailbox)),
            address(rootIcaRouter)
        );

        vm.selectFork({forkId: leafId});
        leafIcaRouter = MockInterchainAccountRouter(BASE_ROUTER_ICA_ADDRESS);
        deployCodeTo(
            'MockInterchainAccountRouter.sol:MockInterchainAccountRouter',
            abi.encode(address(leafMailbox)),
            address(leafIcaRouter)
        );

        /// @dev Use helper contract to override non-virtual handle function in ICA Router
        MockHandleForwarder forwarder =
            new MockHandleForwarder({_icaRouter: address(leafIcaRouter), _mailbox: address(leafMailbox)});
        vm.mockFunction({
            callee: address(leafIcaRouter),
            target: address(forwarder),
            data: abi.encodeWithSelector(InterchainAccountRouter.handle.selector)
        });

        vm.selectFork({forkId: rootId});
        vm.startPrank({msgSender: users.alice});
    }

    function test_executeCrosschainFlow() public {
        uint256 amountIn = USDC_1;
        uint256 amountOutMin = 9e5;

        // Encode destination swap
        bytes memory swapSubplan = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(OPEN_USDT_ADDRESS, int24(1), baseUSDC);
        bytes[] memory swapInputs = new bytes[](1);
        swapInputs[0] = abi.encode(users.alice, amountIn, amountOutMin, path, true, false);

        // Encode fallback transfer
        bytes memory transferSubplan = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory transferInputs = new bytes[](1);
        transferInputs[0] = abi.encode(OPEN_USDT_ADDRESS, users.alice, amountIn);

        // Encode Sub Plan
        bytes memory leafCommands = abi.encodePacked(
            bytes1(uint8(Commands.EXECUTE_SUB_PLAN)) | Commands.FLAG_ALLOW_REVERT,
            bytes1(uint8(Commands.EXECUTE_SUB_PLAN)) | Commands.FLAG_ALLOW_REVERT
        );
        bytes[] memory leafInputs = new bytes[](2);
        leafInputs[0] = abi.encode(swapSubplan, swapInputs);
        leafInputs[1] = abi.encode(transferSubplan, transferInputs);

        // Encode ICA calls
        CallLib.Call[] memory calls = new CallLib.Call[](2);
        calls[0] = CallLib.build({
            to: OPEN_USDT_ADDRESS,
            value: 0,
            data: abi.encodeCall(ERC20.approve, (address(leafRouter), amountIn))
        });
        calls[1] = CallLib.build({
            to: address(leafRouter),
            value: 0,
            data: abi.encodeCall(Dispatcher.execute, (leafCommands, leafInputs))
        });
        // Calculate commitment hash
        bytes32 commitment = hashCommitment(calls);

        // Predict User's ICA address
        address userICA = rootIcaRouter.getRemoteInterchainAccount({
            _destination: leafDomain,
            _owner: address(router),
            _userSalt: TypeCasts.addressToBytes32(users.alice)
        });

        // Encode origin chain commands
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)), bytes1(uint8(Commands.EXECUTE_CROSS_CHAIN)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            userICA,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            amountIn,
            leafDomain
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            rootIcaRouter.isms(leafDomain), // destination ism
            commitment, // commitment of the calls to be made
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute(commands, inputs);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);

        // Process Token Bridging message & check tokens arrived
        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), amountIn);

        // Process Commitment message & check commitment was stored
        leafMailbox.processNextInboundMessage();
        assertEq(leafIcaRouter.verifiedCommitments(userICA), commitment);

        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);

        // Self Relay the message & check swap was successful
        vm.expectEmit(address(leafRouter));
        emit Dispatcher.UniversalRouterSwap(userICA, users.alice);
        vm.startPrank({msgSender: users.alice});
        leafIcaRouter.executeWithCommitment({_interchainAccount: userICA, _calls: calls});

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), 0);
        assertGt(ERC20(baseUSDC).balanceOf(users.alice), amountOutMin);
    }

    function test_executeCrosschainFallback() public {
        uint256 amountIn = USDC_1;
        /// @dev Setting `amountOutMin` too large to simulate swap failure
        uint256 amountOutMin = amountIn * 10;

        // Encode destination swap
        bytes memory swapSubplan = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(OPEN_USDT_ADDRESS, int24(1), baseUSDC);
        bytes[] memory swapInputs = new bytes[](1);
        swapInputs[0] = abi.encode(users.alice, amountIn, amountOutMin, path, true, false);

        // Encode fallback transfer
        bytes memory transferSubplan = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory transferInputs = new bytes[](1);
        transferInputs[0] = abi.encode(OPEN_USDT_ADDRESS, users.alice, amountIn);

        // Encode Sub Plan
        bytes memory leafCommands = abi.encodePacked(
            bytes1(uint8(Commands.EXECUTE_SUB_PLAN)) | Commands.FLAG_ALLOW_REVERT,
            bytes1(uint8(Commands.EXECUTE_SUB_PLAN)) | Commands.FLAG_ALLOW_REVERT
        );
        bytes[] memory leafInputs = new bytes[](2);
        leafInputs[0] = abi.encode(swapSubplan, swapInputs);
        leafInputs[1] = abi.encode(transferSubplan, transferInputs);

        // Encode ICA calls
        CallLib.Call[] memory calls = new CallLib.Call[](2);
        calls[0] = CallLib.build({
            to: OPEN_USDT_ADDRESS,
            value: 0,
            data: abi.encodeCall(ERC20.approve, (address(leafRouter), amountIn))
        });
        calls[1] = CallLib.build({
            to: address(leafRouter),
            value: 0,
            data: abi.encodeCall(Dispatcher.execute, (leafCommands, leafInputs))
        });
        // Calculate commitment hash
        bytes32 commitment = hashCommitment(calls);

        // Predict User's ICA address
        address userICA = rootIcaRouter.getRemoteInterchainAccount({
            _destination: leafDomain,
            _owner: address(router),
            _userSalt: TypeCasts.addressToBytes32(users.alice)
        });

        // Encode origin chain commands
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)), bytes1(uint8(Commands.EXECUTE_CROSS_CHAIN)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            userICA,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            amountIn,
            leafDomain
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            rootIcaRouter.isms(leafDomain), // destination ism
            commitment, // commitment of the calls to be made
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute(commands, inputs);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);

        // Process Token Bridging message & check tokens arrived
        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), amountIn);

        // Process Commitment message & check commitment was stored
        leafMailbox.processNextInboundMessage();
        assertEq(leafIcaRouter.verifiedCommitments(userICA), commitment);

        // Self Relay the message. Swap should fail & fallback transfer should succeed
        vm.expectEmit(OPEN_USDT_ADDRESS);
        emit ERC20.Transfer({from: userICA, to: users.alice, amount: amountIn});
        vm.startPrank({msgSender: users.alice});
        leafIcaRouter.executeWithCommitment({_interchainAccount: userICA, _calls: calls});

        // Swap input is returned to user on destination
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), amountIn);
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);
    }
}
