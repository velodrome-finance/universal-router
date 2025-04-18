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

    /// @dev Fixed fee used for x-chain message quotes
    uint256 public constant MESSAGE_FEE = 1 ether / 10_000; // 0.0001 ETH
    uint256 public constant bridgeMsgFee = MESSAGE_FEE * 2;

    function setUp() public override {
        super.setUp();

        deal(address(users.alice), 1 ether);
        rootIcaRouter = MockInterchainAccountRouter(OPTIMISM_ROUTER_ICA_ADDRESS);
        deployCodeTo(
            'MockInterchainAccountRouter.sol:MockInterchainAccountRouter',
            abi.encode(address(rootMailbox)),
            address(rootIcaRouter)
        );
        /// @dev set custom fee in mailbox's hook
        TestPostDispatchHook(address(rootMailbox.defaultHook())).setFee(MESSAGE_FEE);

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
        vm.deal(users.alice, MESSAGE_FEE * 10);
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
        transferInputs[0] = abi.encode(OPEN_USDT_ADDRESS, users.alice, ActionConstants.CONTRACT_BALANCE);

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
            bridgeMsgFee,
            leafDomain,
            true
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            rootIcaRouter.isms(leafDomain), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute{value: bridgeMsgFee + MESSAGE_FEE}(commands, inputs);

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
        transferInputs[0] = abi.encode(OPEN_USDT_ADDRESS, users.alice, ActionConstants.CONTRACT_BALANCE);

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
            bridgeMsgFee,
            leafDomain,
            true
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            rootIcaRouter.isms(leafDomain), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute{value: bridgeMsgFee + MESSAGE_FEE}(commands, inputs);

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

    function test_executeCrosschainICARefund() public {
        uint256 amount = USDC_1;

        // Predict User's ICA address
        address userICA = rootIcaRouter.getRemoteInterchainAccount({
            _destination: leafDomain,
            _owner: address(router),
            _userSalt: TypeCasts.addressToBytes32(users.alice)
        });

        // Bridge tokens to User's ICA to simulate stuck funds
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            userICA,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            amount,
            bridgeMsgFee,
            leafDomain,
            true
        );

        // Broadcast bridge message
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amount);
        router.execute{value: bridgeMsgFee}(commands, inputs);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);

        // Process Token Bridging message & check tokens arrived
        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), amount);

        vm.selectFork(rootId);

        // Encode refund ICA call
        CallLib.Call[] memory calls = new CallLib.Call[](1);
        calls[0] = CallLib.build({
            to: OPEN_USDT_ADDRESS,
            value: 0,
            data: abi.encodeCall(ERC20.transfer, (users.alice, amount))
        });

        // Calculate commitment hash
        bytes32 commitment = hashCommitment(calls);

        // Encode origin chain command
        commands = abi.encodePacked(bytes1(uint8(Commands.EXECUTE_CROSS_CHAIN)));
        inputs[0] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            rootIcaRouter.isms(leafDomain), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );
        router.execute{value: MESSAGE_FEE}(commands, inputs);

        // Process Commitment message & check commitment was stored
        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        assertEq(leafIcaRouter.verifiedCommitments(userICA), commitment);

        // Self Relay the message. Refund transfer should be executed
        vm.expectEmit(OPEN_USDT_ADDRESS);
        emit ERC20.Transfer({from: userICA, to: users.alice, amount: amount});
        vm.startPrank({msgSender: users.alice});
        leafIcaRouter.executeWithCommitment({_interchainAccount: userICA, _calls: calls});

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), amount);
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
    }

    function test_RevertWhen_executeCrosschainInsufficientFee() public {
        uint256 amountIn = USDC_1;
        uint256 amountOutMin = 9e5;
        /// @dev Insufficient message fee
        uint256 msgFee = MESSAGE_FEE - 1;

        (,, bytes memory commands, bytes[] memory inputs) =
            _executeCrosschainParams({_amountIn: amountIn, _amountOutMin: amountOutMin, _msgFee: msgFee});

        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        vm.expectRevert(); // OutOfFunds
        router.execute{value: bridgeMsgFee}(commands, inputs);
    }

    function test_RevertWhen_executeCrosschainFeeGreaterThanContractBalance() public {
        uint256 amountIn = USDC_1;
        uint256 amountOutMin = 9e5;

        (,, bytes memory commands, bytes[] memory inputs) =
            _executeCrosschainParams({_amountIn: amountIn, _amountOutMin: amountOutMin, _msgFee: MESSAGE_FEE});

        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        vm.expectRevert(); // OutOfFunds
        router.execute{value: bridgeMsgFee}(commands, inputs); // @dev Fee only covers x-chain bridge command
    }

    function testGas_executeCrosschainOriginSuccess() public {
        uint256 amountIn = USDC_1;
        uint256 amountOutMin = 9e5;

        (,, bytes memory commands, bytes[] memory inputs) =
            _executeCrosschainParams({_amountIn: amountIn, _amountOutMin: amountOutMin, _msgFee: MESSAGE_FEE});

        deal(OPEN_USDT_ADDRESS, users.alice, amountIn);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute{value: bridgeMsgFee + MESSAGE_FEE}(commands, inputs);
        vm.snapshotGasLastCall('UniversalRouter_ExecuteCrossChain_Origin_Success');
    }

    function testGas_executeCrosschainOriginFallback() public {
        uint256 amountIn = USDC_1;
        /// @dev Setting `amountOutMin` too large to simulate swap failure
        uint256 amountOutMin = amountIn * 10;

        (,, bytes memory commands, bytes[] memory inputs) =
            _executeCrosschainParams({_amountIn: amountIn, _amountOutMin: amountOutMin, _msgFee: MESSAGE_FEE});

        deal(OPEN_USDT_ADDRESS, users.alice, amountIn);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute{value: bridgeMsgFee + MESSAGE_FEE}(commands, inputs);
        vm.snapshotGasLastCall('UniversalRouter_ExecuteCrossChain_Origin_Fallback');
    }

    function testGas_executeCrosschainDestinationSuccess() public {
        uint256 amountIn = USDC_1;
        uint256 amountOutMin = 9e5;

        (address userICA, CallLib.Call[] memory calls, bytes memory commands, bytes[] memory inputs) =
            _executeCrosschainParams({_amountIn: amountIn, _amountOutMin: amountOutMin, _msgFee: MESSAGE_FEE});

        deal(OPEN_USDT_ADDRESS, users.alice, amountIn);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute{value: bridgeMsgFee + MESSAGE_FEE}(commands, inputs);

        // Process Token Bridging & Commitment messages
        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        leafMailbox.processNextInboundMessage();

        // Self Relay the message
        vm.startPrank({msgSender: users.alice});
        leafIcaRouter.executeWithCommitment({_interchainAccount: userICA, _calls: calls});
        vm.snapshotGasLastCall('UniversalRouter_ExecuteCrossChain_Destination_Success');
    }

    function testGas_executeCrosschainDestinationFallback() public {
        uint256 amountIn = USDC_1;
        /// @dev Setting `amountOutMin` too large to simulate swap failure
        uint256 amountOutMin = amountIn * 10;

        (address userICA, CallLib.Call[] memory calls, bytes memory commands, bytes[] memory inputs) =
            _executeCrosschainParams({_amountIn: amountIn, _amountOutMin: amountOutMin, _msgFee: MESSAGE_FEE});

        deal(OPEN_USDT_ADDRESS, users.alice, amountIn);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute{value: bridgeMsgFee + MESSAGE_FEE}(commands, inputs);

        // Process Token Bridging & Commitment messages
        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        leafMailbox.processNextInboundMessage();

        // Self Relay the message
        vm.startPrank({msgSender: users.alice});
        leafIcaRouter.executeWithCommitment({_interchainAccount: userICA, _calls: calls});
        vm.snapshotGasLastCall('UniversalRouter_ExecuteCrossChain_Destination_Fallback');
    }

    /// @dev Helper to generate the parameters for valid execute x-chain calls
    function _executeCrosschainParams(uint256 _amountIn, uint256 _amountOutMin, uint256 _msgFee)
        internal
        view
        returns (address userICA, CallLib.Call[] memory calls, bytes memory commands, bytes[] memory inputs)
    {
        // Encode destination swap
        bytes memory swapSubplan = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(OPEN_USDT_ADDRESS, int24(1), baseUSDC);
        bytes[] memory swapInputs = new bytes[](1);
        swapInputs[0] = abi.encode(users.alice, _amountIn, _amountOutMin, path, true, false);

        // Encode fallback transfer
        bytes memory transferSubplan = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory transferInputs = new bytes[](1);
        transferInputs[0] = abi.encode(OPEN_USDT_ADDRESS, users.alice, ActionConstants.CONTRACT_BALANCE);

        // Encode Sub Plan
        bytes memory leafCommands = abi.encodePacked(
            bytes1(uint8(Commands.EXECUTE_SUB_PLAN)) | Commands.FLAG_ALLOW_REVERT,
            bytes1(uint8(Commands.EXECUTE_SUB_PLAN)) | Commands.FLAG_ALLOW_REVERT
        );
        bytes[] memory leafInputs = new bytes[](2);
        leafInputs[0] = abi.encode(swapSubplan, swapInputs);
        leafInputs[1] = abi.encode(transferSubplan, transferInputs);

        // Encode ICA calls
        calls = new CallLib.Call[](2);
        calls[0] = CallLib.build({
            to: OPEN_USDT_ADDRESS,
            value: 0,
            data: abi.encodeCall(ERC20.approve, (address(leafRouter), _amountIn))
        });
        calls[1] = CallLib.build({
            to: address(leafRouter),
            value: 0,
            data: abi.encodeCall(Dispatcher.execute, (leafCommands, leafInputs))
        });
        // Calculate commitment hash
        bytes32 commitment = hashCommitment(calls);

        // Predict User's ICA address
        userICA = rootIcaRouter.getRemoteInterchainAccount({
            _destination: leafDomain,
            _owner: address(router),
            _userSalt: TypeCasts.addressToBytes32(users.alice)
        });

        // Encode origin chain commands
        commands = abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)), bytes1(uint8(Commands.EXECUTE_CROSS_CHAIN)));
        inputs = new bytes[](2);
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            userICA,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            _amountIn,
            bridgeMsgFee,
            leafDomain,
            true
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            rootIcaRouter.isms(leafDomain), // destination ism
            commitment, // commitment of the calls to be made
            _msgFee, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );
    }
}
