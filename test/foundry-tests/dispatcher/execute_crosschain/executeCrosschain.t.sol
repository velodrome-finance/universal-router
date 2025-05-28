// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {InterchainAccountRouter} from '@hyperlane-updated/contracts/middleware/InterchainAccountRouter.sol';
import {StandardHookMetadata} from '@hyperlane/core/contracts/hooks/libs/StandardHookMetadata.sol';
import {IPostDispatchHook} from '@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol';
import {OwnableMulticall} from '@hyperlane-updated/contracts/middleware/libs/OwnableMulticall.sol';
import {TypeCasts} from '@hyperlane/core/contracts/libs/TypeCasts.sol';

import {IInterchainAccountRouter} from 'contracts/interfaces/external/IInterchainAccountRouter.sol';
import {IRouterClient} from 'contracts/interfaces/external/IRouterClient.sol';
import {BridgeTypes} from 'contracts/libraries/BridgeTypes.sol';

import '../../BaseForkFixture.t.sol';

contract ExecuteCrossChainTest is BaseForkFixture {
    InterchainAccountRouter public rootIcaRouter;
    InterchainAccountRouter public leafIcaRouter;

    IPoolFactory public constant v2Factory = IPoolFactory(0x420DD381b31aEf6683db6B902084cB0FFECe40Da);
    address public constant baseUSDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    /// @dev Fixed fee used for x-chain message quotes
    uint256 public constant MESSAGE_FEE = 1 ether / 10_000; // 0.0001 ETH

    function setUp() public override {
        super.setUp();

        deal(address(users.alice), 1 ether);
        rootIcaRouter = InterchainAccountRouter(OPTIMISM_ROUTER_ICA_ADDRESS);
        address hook = address(rootIcaRouter.hook());
        address owner = rootIcaRouter.owner();
        // @dev value used in HL tests
        uint256 commitGasUsage = 20_000;
        deployCodeTo(
            'InterchainAccountRouter.sol:InterchainAccountRouter',
            abi.encode(address(rootMailbox), hook, owner, commitGasUsage),
            address(rootIcaRouter)
        );

        vm.selectFork({forkId: leafId});
        leafIcaRouter = InterchainAccountRouter(BASE_ROUTER_ICA_ADDRESS);
        hook = address(leafIcaRouter.hook());
        owner = leafIcaRouter.owner();
        deployCodeTo(
            'InterchainAccountRouter.sol:InterchainAccountRouter',
            abi.encode(address(leafMailbox), hook, owner, commitGasUsage),
            address(leafIcaRouter)
        );

        createAndSeedPair(baseUSDC, OPEN_USDT_ADDRESS, false);

        vm.selectFork({forkId: rootId});
        vm.deal(users.alice, MESSAGE_FEE * 10);
        vm.startPrank({msgSender: users.alice});
    }

    function test_executeCrosschainFlowV3SwapExactIn() public {
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
        bytes32 commitment = hashCommitment({_calls: calls, _salt: TypeCasts.addressToBytes32(users.alice)});

        // Predict User's ICA address
        address payable userICA = payable(
            rootIcaRouter.getRemoteInterchainAccount({
                _destination: leafDomain,
                _owner: address(router),
                _userSalt: TypeCasts.addressToBytes32(users.alice)
            })
        );

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
            MESSAGE_FEE,
            leafDomain,
            true
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            bytes32(0), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        vm.expectCall({
            callee: address(rootIcaRouter),
            data: abi.encodeCall(
                IInterchainAccountRouter.callRemoteCommitReveal,
                (
                    leafDomain,
                    rootIcaRouter.routers(leafDomain),
                    bytes32(0),
                    new bytes(0),
                    IPostDispatchHook(address(rootIcaRouter.hook())),
                    TypeCasts.addressToBytes32(users.alice),
                    commitment
                )
            )
        });

        vm.expectEmit(address(router));
        emit Dispatcher.CrossChainSwap({
            caller: users.alice,
            localRouter: address(rootIcaRouter),
            destinationDomain: leafDomain,
            commitment: commitment
        });

        router.execute{value: MESSAGE_FEE * 2}(commands, inputs);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);

        // Process Token Bridging message & check tokens arrived
        vm.selectFork(leafId);
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS),
            recipient: address(leafOpenUsdtTokenBridge)
        });
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), amountIn);

        // Process Commitment message & check commitment was stored
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(address(rootIcaRouter)),
            recipient: address(leafIcaRouter)
        });
        leafMailbox.processNextInboundMessage();
        assertTrue(OwnableMulticall(userICA).commitments(commitment));

        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);

        // Self Relay the message & check swap was successful
        vm.expectEmit(address(leafRouter));
        emit Dispatcher.UniversalRouterSwap(userICA, users.alice);
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), 0); // no leftover input from swap in exactIn
        assertGt(ERC20(baseUSDC).balanceOf(users.alice), amountOutMin);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(userICA, address(leafRouter)), 0);
    }

    function test_executeCrosschainFlowV3SwapExactOut() public {
        uint256 amountOut = 9e5;
        uint256 amountInMax = USDC_1;

        // Encode destination swap
        bytes memory swapSubplan = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));
        bytes memory path = abi.encodePacked(baseUSDC, int24(1), OPEN_USDT_ADDRESS);
        bytes[] memory swapInputs = new bytes[](1);
        swapInputs[0] = abi.encode(users.alice, amountOut, amountInMax, path, true, false);

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
            data: abi.encodeCall(ERC20.approve, (address(leafRouter), amountInMax))
        });
        calls[1] = CallLib.build({
            to: address(leafRouter),
            value: 0,
            data: abi.encodeCall(Dispatcher.execute, (leafCommands, leafInputs))
        });

        // Calculate commitment hash
        bytes32 commitment = hashCommitment({_calls: calls, _salt: TypeCasts.addressToBytes32(users.alice)});

        // Predict User's ICA address
        address payable userICA = payable(
            rootIcaRouter.getRemoteInterchainAccount({
                _destination: leafDomain,
                _owner: address(router),
                _userSalt: TypeCasts.addressToBytes32(users.alice)
            })
        );

        // Encode origin chain commands
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)), bytes1(uint8(Commands.EXECUTE_CROSS_CHAIN)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            userICA,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            amountInMax,
            MESSAGE_FEE,
            leafDomain,
            true
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            bytes32(0), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountInMax);
        vm.expectCall({
            callee: address(rootIcaRouter),
            data: abi.encodeCall(
                IInterchainAccountRouter.callRemoteCommitReveal,
                (
                    leafDomain,
                    rootIcaRouter.routers(leafDomain),
                    bytes32(0),
                    new bytes(0),
                    IPostDispatchHook(address(rootIcaRouter.hook())),
                    TypeCasts.addressToBytes32(users.alice),
                    commitment
                )
            )
        });

        vm.expectEmit(address(router));
        emit Dispatcher.CrossChainSwap({
            caller: users.alice,
            localRouter: address(rootIcaRouter),
            destinationDomain: leafDomain,
            commitment: commitment
        });

        router.execute{value: MESSAGE_FEE * 2}(commands, inputs);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);

        // Process Token Bridging message & check tokens arrived
        vm.selectFork(leafId);
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS),
            recipient: address(leafOpenUsdtTokenBridge)
        });
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), amountInMax);

        // Process Commitment message & check commitment was stored
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(address(rootIcaRouter)),
            recipient: address(leafIcaRouter)
        });
        leafMailbox.processNextInboundMessage();
        assertTrue(OwnableMulticall(userICA).commitments(commitment));

        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);

        // Self Relay the message & check swap was successful
        vm.expectEmit(address(leafRouter));
        emit Dispatcher.UniversalRouterSwap(userICA, users.alice);
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), 99599); //leftover from swap is sent to user
        assertEq(ERC20(baseUSDC).balanceOf(users.alice), amountOut);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(userICA, address(leafRouter)), 0);
    }

    function test_executeCrosschainFlowV2SwapExactIn() public {
        uint256 amountIn = USDC_1;
        uint256 amountOutMin = 9e5;

        // Encode destination swap
        bytes memory swapSubplan = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(OPEN_USDT_ADDRESS, false, baseUSDC);
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
        bytes32 commitment = hashCommitment({_calls: calls, _salt: TypeCasts.addressToBytes32(users.alice)});

        // Predict User's ICA address
        address payable userICA = payable(
            rootIcaRouter.getRemoteInterchainAccount({
                _destination: leafDomain,
                _owner: address(router),
                _userSalt: TypeCasts.addressToBytes32(users.alice)
            })
        );

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
            MESSAGE_FEE,
            leafDomain,
            true
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            bytes32(0), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        vm.expectCall({
            callee: address(rootIcaRouter),
            data: abi.encodeCall(
                IInterchainAccountRouter.callRemoteCommitReveal,
                (
                    leafDomain,
                    rootIcaRouter.routers(leafDomain),
                    bytes32(0),
                    new bytes(0),
                    IPostDispatchHook(address(rootIcaRouter.hook())),
                    TypeCasts.addressToBytes32(users.alice),
                    commitment
                )
            )
        });

        vm.expectEmit(address(router));
        emit Dispatcher.CrossChainSwap({
            caller: users.alice,
            localRouter: address(rootIcaRouter),
            destinationDomain: leafDomain,
            commitment: commitment
        });

        router.execute{value: MESSAGE_FEE * 2}(commands, inputs);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);

        // Process Token Bridging message & check tokens arrived
        vm.selectFork(leafId);
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS),
            recipient: address(leafOpenUsdtTokenBridge)
        });
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), amountIn);

        // Process Commitment message & check commitment was stored
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(address(rootIcaRouter)),
            recipient: address(leafIcaRouter)
        });
        leafMailbox.processNextInboundMessage();
        assertTrue(OwnableMulticall(userICA).commitments(commitment));

        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);

        // Self Relay the message & check swap was successful
        vm.expectEmit(address(leafRouter));
        emit Dispatcher.UniversalRouterSwap(userICA, users.alice);
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), 0); //no leftover from swap in exactIn
        assertGt(ERC20(baseUSDC).balanceOf(users.alice), amountOutMin);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(userICA, address(leafRouter)), 0);
    }

    function test_executeCrosschainFlowV2SwapExactOut() public {
        uint256 amountOut = 9e5;
        uint256 amountInMax = USDC_1;

        // Encode destination swap
        bytes memory swapSubplan = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
        bytes memory path = abi.encodePacked(OPEN_USDT_ADDRESS, false, baseUSDC);
        bytes[] memory swapInputs = new bytes[](1);
        swapInputs[0] = abi.encode(users.alice, amountOut, amountInMax, path, true, false);

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
            data: abi.encodeCall(ERC20.approve, (address(leafRouter), amountInMax))
        });
        calls[1] = CallLib.build({
            to: address(leafRouter),
            value: 0,
            data: abi.encodeCall(Dispatcher.execute, (leafCommands, leafInputs))
        });

        // Calculate commitment hash
        bytes32 commitment = hashCommitment({_calls: calls, _salt: TypeCasts.addressToBytes32(users.alice)});

        // Predict User's ICA address
        address payable userICA = payable(
            rootIcaRouter.getRemoteInterchainAccount({
                _destination: leafDomain,
                _owner: address(router),
                _userSalt: TypeCasts.addressToBytes32(users.alice)
            })
        );

        // Encode origin chain commands
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)), bytes1(uint8(Commands.EXECUTE_CROSS_CHAIN)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            userICA,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            amountInMax,
            MESSAGE_FEE,
            leafDomain,
            true
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            bytes32(0), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountInMax);
        vm.expectCall({
            callee: address(rootIcaRouter),
            data: abi.encodeCall(
                IInterchainAccountRouter.callRemoteCommitReveal,
                (
                    leafDomain,
                    rootIcaRouter.routers(leafDomain),
                    bytes32(0),
                    new bytes(0),
                    IPostDispatchHook(address(rootIcaRouter.hook())),
                    TypeCasts.addressToBytes32(users.alice),
                    commitment
                )
            )
        });

        vm.expectEmit(address(router));
        emit Dispatcher.CrossChainSwap({
            caller: users.alice,
            localRouter: address(rootIcaRouter),
            destinationDomain: leafDomain,
            commitment: commitment
        });

        router.execute{value: MESSAGE_FEE * 2}(commands, inputs);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);

        // Process Token Bridging message & check tokens arrived
        vm.selectFork(leafId);
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS),
            recipient: address(leafOpenUsdtTokenBridge)
        });
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), amountInMax);

        // Process Commitment message & check commitment was stored
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(address(rootIcaRouter)),
            recipient: address(leafIcaRouter)
        });
        leafMailbox.processNextInboundMessage();
        assertTrue(OwnableMulticall(userICA).commitments(commitment));

        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);

        // Self Relay the message & check swap was successful
        vm.expectEmit(address(leafRouter));
        emit Dispatcher.UniversalRouterSwap(userICA, users.alice);
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), 89094); //leftover from swap is sent to user
        assertGe(ERC20(baseUSDC).balanceOf(users.alice), amountOut);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(userICA, address(leafRouter)), 0);
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
        bytes32 commitment = hashCommitment({_calls: calls, _salt: TypeCasts.addressToBytes32(users.alice)});

        // Predict User's ICA address
        address payable userICA = payable(
            rootIcaRouter.getRemoteInterchainAccount({
                _destination: leafDomain,
                _owner: address(router),
                _userSalt: TypeCasts.addressToBytes32(users.alice)
            })
        );

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
            MESSAGE_FEE,
            leafDomain,
            true
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            bytes32(0), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        vm.expectCall({
            callee: address(rootIcaRouter),
            data: abi.encodeCall(
                IInterchainAccountRouter.callRemoteCommitReveal,
                (
                    leafDomain,
                    rootIcaRouter.routers(leafDomain),
                    bytes32(0),
                    new bytes(0),
                    IPostDispatchHook(address(rootIcaRouter.hook())),
                    TypeCasts.addressToBytes32(users.alice),
                    commitment
                )
            )
        });

        vm.expectEmit(address(router));
        emit Dispatcher.CrossChainSwap({
            caller: users.alice,
            localRouter: address(rootIcaRouter),
            destinationDomain: leafDomain,
            commitment: commitment
        });

        router.execute{value: MESSAGE_FEE * 2}(commands, inputs);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);

        // Process Token Bridging message & check tokens arrived
        vm.selectFork(leafId);
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS),
            recipient: address(leafOpenUsdtTokenBridge)
        });
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), amountIn);

        // Process Commitment message & check commitment was stored
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(address(rootIcaRouter)),
            recipient: address(leafIcaRouter)
        });
        leafMailbox.processNextInboundMessage();
        assertTrue(OwnableMulticall(userICA).commitments(commitment));

        // Self Relay the message. Swap should fail & fallback transfer should succeed
        vm.expectEmit(OPEN_USDT_ADDRESS);
        emit ERC20.Transfer({from: userICA, to: users.alice, amount: amountIn});
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});

        // Swap input is returned to user on destination
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), amountIn);
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(userICA, address(leafRouter)), 0);
    }

    function test_executeCrosschainFlowMixedV3ExactInV2ExactIn() public {
        uint256 v3AmountIn = USDC_1;
        uint256 v3AmountOutMin = 999000;

        // Encode destination swaps & sweep
        bytes memory swapSubplan = abi.encodePacked(
            bytes1(uint8(Commands.V3_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.V2_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.SWEEP))
        );
        bytes[] memory swapInputs = new bytes[](3);

        // V3 Swap Inputs
        bytes memory v3Path = abi.encodePacked(OPEN_USDT_ADDRESS, int24(1), baseUSDC);
        swapInputs[0] = abi.encode(ActionConstants.ADDRESS_THIS, v3AmountIn, v3AmountOutMin, v3Path, true, false);

        // V2 Swap Inputs
        uint256 v2AmountIn = v3AmountOutMin;
        uint256 v2AmountOutMin = 606500898800000;
        bytes memory v2Path = abi.encodePacked(baseUSDC, false, WETH9_ADDRESS);
        swapInputs[1] = abi.encode(users.alice, v2AmountIn, v2AmountOutMin, v2Path, false, false);

        // Sweep leftover intermediary tokens to recipient
        swapInputs[2] = abi.encode(baseUSDC, users.alice, 0);

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
            data: abi.encodeCall(ERC20.approve, (address(leafRouter), v3AmountIn))
        });
        calls[1] = CallLib.build({
            to: address(leafRouter),
            value: 0,
            data: abi.encodeCall(Dispatcher.execute, (leafCommands, leafInputs))
        });

        // Calculate commitment hash
        bytes32 commitment = hashCommitment({_calls: calls, _salt: TypeCasts.addressToBytes32(users.alice)});

        // Predict User's ICA address
        address payable userICA = payable(
            rootIcaRouter.getRemoteInterchainAccount({
                _destination: leafDomain,
                _owner: address(router),
                _userSalt: TypeCasts.addressToBytes32(users.alice)
            })
        );

        // Encode origin chain commands
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)), bytes1(uint8(Commands.EXECUTE_CROSS_CHAIN)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            userICA,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            v3AmountIn,
            MESSAGE_FEE,
            leafDomain,
            true
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            bytes32(0), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, v3AmountIn);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), v3AmountIn);
        vm.expectCall({
            callee: address(rootIcaRouter),
            data: abi.encodeCall(
                IInterchainAccountRouter.callRemoteCommitReveal,
                (
                    leafDomain,
                    rootIcaRouter.routers(leafDomain),
                    bytes32(0),
                    new bytes(0),
                    IPostDispatchHook(address(rootIcaRouter.hook())),
                    TypeCasts.addressToBytes32(users.alice),
                    commitment
                )
            )
        });

        vm.expectEmit(address(router));
        emit Dispatcher.CrossChainSwap({
            caller: users.alice,
            localRouter: address(rootIcaRouter),
            destinationDomain: leafDomain,
            commitment: commitment
        });

        router.execute{value: MESSAGE_FEE * 2}(commands, inputs);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);

        // Select Leaf & avoid underflow
        vm.selectFork(leafId);
        IPool pool = IPool(v2Factory.getPool(baseUSDC, WETH9_ADDRESS, false));
        uint256 last = pool.blockTimestampLast();

        // Set timestamp greater than last timestamp in Pool to avoid underflow
        vm.warp(last + 1);

        // Process Token Bridging message & check tokens arrived
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS),
            recipient: address(leafOpenUsdtTokenBridge)
        });
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), v3AmountIn);

        // Process Commitment message & check commitment was stored
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(address(rootIcaRouter)),
            recipient: address(leafIcaRouter)
        });
        leafMailbox.processNextInboundMessage();
        assertTrue(OwnableMulticall(userICA).commitments(commitment));

        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);
        assertEq(ERC20(WETH9_ADDRESS).balanceOf(users.alice), 0);

        // Self Relay the message & check both swaps were successful
        vm.expectEmit(address(leafRouter));
        emit Dispatcher.UniversalRouterSwap({sender: userICA, recipient: address(leafRouter)});
        vm.expectEmit(address(leafRouter));
        emit Dispatcher.UniversalRouterSwap(userICA, users.alice);
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});

        // No leftover in the Router
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(address(leafRouter)), 0);
        assertEq(ERC20(baseUSDC).balanceOf(address(leafRouter)), 0);
        assertEq(ERC20(WETH9_ADDRESS).balanceOf(address(leafRouter)), 0);

        // No leftover in the ICA
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
        assertEq(ERC20(baseUSDC).balanceOf(userICA), 0); // leftover intermediary tokens swept from ICA
        assertEq(ERC20(WETH9_ADDRESS).balanceOf(userICA), 0);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), 0); // no leftover input from v3 exactIn swap
        assertApproxEqAbs(ERC20(baseUSDC).balanceOf(users.alice), 0, 1e3); // most output from first swap has been used by second swap
        assertGe(ERC20(WETH9_ADDRESS).balanceOf(users.alice), v2AmountOutMin);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(userICA, address(leafRouter)), 0);
    }

    function test_executeCrosschainFlowMixedV3ExactInV2ExactInFirstSwapRevert() public {
        uint256 v3AmountIn = USDC_1;
        /// @dev Large v3AmountOutMin to simulate failure
        uint256 v3AmountOutMin = 999000 * 2;

        // Encode destination swaps & sweep
        bytes memory swapSubplan = abi.encodePacked(
            bytes1(uint8(Commands.V3_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.V2_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.SWEEP))
        );
        bytes[] memory swapInputs = new bytes[](3);

        // V3 Swap Inputs
        bytes memory v3Path = abi.encodePacked(OPEN_USDT_ADDRESS, int24(1), baseUSDC);
        swapInputs[0] = abi.encode(ActionConstants.ADDRESS_THIS, v3AmountIn, v3AmountOutMin, v3Path, true, false);

        // V2 Swap Inputs
        uint256 v2AmountIn = v3AmountOutMin;
        uint256 v2AmountOutMin = 606500898800000;
        bytes memory v2Path = abi.encodePacked(baseUSDC, false, WETH9_ADDRESS);
        swapInputs[1] = abi.encode(users.alice, v2AmountIn, v2AmountOutMin, v2Path, false, false);

        // Sweep leftover intermediary tokens to recipient
        swapInputs[2] = abi.encode(baseUSDC, users.alice, 0);

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
            data: abi.encodeCall(ERC20.approve, (address(leafRouter), v3AmountIn))
        });
        calls[1] = CallLib.build({
            to: address(leafRouter),
            value: 0,
            data: abi.encodeCall(Dispatcher.execute, (leafCommands, leafInputs))
        });

        // Calculate commitment hash
        bytes32 commitment = hashCommitment({_calls: calls, _salt: TypeCasts.addressToBytes32(users.alice)});

        // Predict User's ICA address
        address payable userICA = payable(
            rootIcaRouter.getRemoteInterchainAccount({
                _destination: leafDomain,
                _owner: address(router),
                _userSalt: TypeCasts.addressToBytes32(users.alice)
            })
        );

        // Encode origin chain commands
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)), bytes1(uint8(Commands.EXECUTE_CROSS_CHAIN)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            userICA,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            v3AmountIn,
            MESSAGE_FEE,
            leafDomain,
            true
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            bytes32(0), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, v3AmountIn);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), v3AmountIn);
        vm.expectCall({
            callee: address(rootIcaRouter),
            data: abi.encodeCall(
                IInterchainAccountRouter.callRemoteCommitReveal,
                (
                    leafDomain,
                    rootIcaRouter.routers(leafDomain),
                    bytes32(0),
                    new bytes(0),
                    IPostDispatchHook(address(rootIcaRouter.hook())),
                    TypeCasts.addressToBytes32(users.alice),
                    commitment
                )
            )
        });

        vm.expectEmit(address(router));
        emit Dispatcher.CrossChainSwap({
            caller: users.alice,
            localRouter: address(rootIcaRouter),
            destinationDomain: leafDomain,
            commitment: commitment
        });

        router.execute{value: MESSAGE_FEE * 2}(commands, inputs);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);

        // Select Leaf & avoid underflow
        vm.selectFork(leafId);
        IPool pool = IPool(v2Factory.getPool(baseUSDC, WETH9_ADDRESS, false));
        uint256 last = pool.blockTimestampLast();

        // Set timestamp greater than last timestamp in Pool to avoid underflow
        vm.warp(last + 1);

        // Process Token Bridging message & check tokens arrived
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS),
            recipient: address(leafOpenUsdtTokenBridge)
        });
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), v3AmountIn);

        // Process Commitment message & check commitment was stored
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(address(rootIcaRouter)),
            recipient: address(leafIcaRouter)
        });
        leafMailbox.processNextInboundMessage();
        assertTrue(OwnableMulticall(userICA).commitments(commitment));

        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);
        assertEq(ERC20(WETH9_ADDRESS).balanceOf(users.alice), 0);

        // Self Relay the message. Swaps should fail & fallback transfer should succeed
        vm.expectEmit(OPEN_USDT_ADDRESS);
        emit ERC20.Transfer({from: userICA, to: users.alice, amount: v3AmountIn});
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});

        // No leftover in the Router
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(address(leafRouter)), 0);
        assertEq(ERC20(baseUSDC).balanceOf(address(leafRouter)), 0);
        assertEq(ERC20(WETH9_ADDRESS).balanceOf(address(leafRouter)), 0);

        // No leftover in the ICA
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
        assertEq(ERC20(baseUSDC).balanceOf(userICA), 0);
        assertEq(ERC20(WETH9_ADDRESS).balanceOf(userICA), 0);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), v3AmountIn);
        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);
        assertEq(ERC20(WETH9_ADDRESS).balanceOf(users.alice), 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(userICA, address(leafRouter)), 0);
    }

    function test_executeCrosschainFlowMixedV3ExactInV2ExactInSecondSwapRevert() public {
        uint256 v3AmountIn = USDC_1;
        uint256 v3AmountOutMin = 999000;

        // Encode destination swaps & sweep
        bytes memory swapSubplan = abi.encodePacked(
            bytes1(uint8(Commands.V3_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.V2_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.SWEEP))
        );
        bytes[] memory swapInputs = new bytes[](3);

        // V3 Swap Inputs
        bytes memory v3Path = abi.encodePacked(OPEN_USDT_ADDRESS, int24(1), baseUSDC);
        swapInputs[0] = abi.encode(ActionConstants.ADDRESS_THIS, v3AmountIn, v3AmountOutMin, v3Path, true, false);

        // V2 Swap Inputs
        uint256 v2AmountIn = v3AmountOutMin;
        /// @dev Large v2AmountOutMin to simulate failure
        uint256 v2AmountOutMin = 606500898800000 * 2;
        bytes memory v2Path = abi.encodePacked(baseUSDC, false, WETH9_ADDRESS);
        swapInputs[1] = abi.encode(users.alice, v2AmountIn, v2AmountOutMin, v2Path, false, false);

        // Sweep leftover intermediary tokens to recipient
        swapInputs[2] = abi.encode(baseUSDC, users.alice, 0);

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
            data: abi.encodeCall(ERC20.approve, (address(leafRouter), v3AmountIn))
        });
        calls[1] = CallLib.build({
            to: address(leafRouter),
            value: 0,
            data: abi.encodeCall(Dispatcher.execute, (leafCommands, leafInputs))
        });

        // Calculate commitment hash
        bytes32 commitment = hashCommitment({_calls: calls, _salt: TypeCasts.addressToBytes32(users.alice)});

        // Predict User's ICA address
        address payable userICA = payable(
            rootIcaRouter.getRemoteInterchainAccount({
                _destination: leafDomain,
                _owner: address(router),
                _userSalt: TypeCasts.addressToBytes32(users.alice)
            })
        );

        // Encode origin chain commands
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)), bytes1(uint8(Commands.EXECUTE_CROSS_CHAIN)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            userICA,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            v3AmountIn,
            MESSAGE_FEE,
            leafDomain,
            true
        );
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            bytes32(0), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, v3AmountIn);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), v3AmountIn);
        vm.expectCall({
            callee: address(rootIcaRouter),
            data: abi.encodeCall(
                IInterchainAccountRouter.callRemoteCommitReveal,
                (
                    leafDomain,
                    rootIcaRouter.routers(leafDomain),
                    bytes32(0),
                    new bytes(0),
                    IPostDispatchHook(address(rootIcaRouter.hook())),
                    TypeCasts.addressToBytes32(users.alice),
                    commitment
                )
            )
        });

        vm.expectEmit(address(router));
        emit Dispatcher.CrossChainSwap({
            caller: users.alice,
            localRouter: address(rootIcaRouter),
            destinationDomain: leafDomain,
            commitment: commitment
        });

        router.execute{value: MESSAGE_FEE * 2}(commands, inputs);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);

        // Select Leaf & avoid underflow
        vm.selectFork(leafId);
        IPool pool = IPool(v2Factory.getPool(baseUSDC, WETH9_ADDRESS, false));
        uint256 last = pool.blockTimestampLast();

        // Set timestamp greater than last timestamp in Pool to avoid underflow
        vm.warp(last + 1);

        // Process Token Bridging message & check tokens arrived
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS),
            recipient: address(leafOpenUsdtTokenBridge)
        });
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), v3AmountIn);

        // Process Commitment message & check commitment was stored
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(address(rootIcaRouter)),
            recipient: address(leafIcaRouter)
        });
        leafMailbox.processNextInboundMessage();
        assertTrue(OwnableMulticall(userICA).commitments(commitment));

        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);
        assertEq(ERC20(WETH9_ADDRESS).balanceOf(users.alice), 0);

        // Self Relay the message. Swaps should fail & fallback transfer should succeed
        vm.expectEmit(OPEN_USDT_ADDRESS);
        emit ERC20.Transfer({from: userICA, to: users.alice, amount: v3AmountIn});
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});

        // No leftover in the Router
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(address(leafRouter)), 0);
        assertEq(ERC20(baseUSDC).balanceOf(address(leafRouter)), 0);
        assertEq(ERC20(WETH9_ADDRESS).balanceOf(address(leafRouter)), 0);

        // No leftover in the ICA
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
        assertEq(ERC20(baseUSDC).balanceOf(userICA), 0);
        assertEq(ERC20(WETH9_ADDRESS).balanceOf(userICA), 0);

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), v3AmountIn);
        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);
        assertEq(ERC20(WETH9_ADDRESS).balanceOf(users.alice), 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(userICA, address(leafRouter)), 0);
    }

    function test_executeCrosschainFlowV3SwapExactInETHRefund() public {
        uint256 amountIn = USDC_1;
        uint256 amountOutMin = 9e5;
        uint256 leftoverETH = MESSAGE_FEE / 2;

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
        bytes32 commitment = hashCommitment({_calls: calls, _salt: TypeCasts.addressToBytes32(users.alice)});

        // Predict User's ICA address
        address payable userICA = payable(
            rootIcaRouter.getRemoteInterchainAccount({
                _destination: leafDomain,
                _owner: address(router),
                _userSalt: TypeCasts.addressToBytes32(users.alice)
            })
        );

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
            MESSAGE_FEE,
            leafDomain,
            true
        );
        bytes memory hookMetadata = StandardHookMetadata.formatMetadata({
            _msgValue: uint256(0),
            _gasLimit: HypXERC20(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS).destinationGas(rootDomain),
            _refundAddress: users.alice,
            _customMetadata: ''
        });
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            bytes32(0), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE + leftoverETH, // fee to dispatch x-chain message
            IPostDispatchHook(address(rootIcaRouter.hook())), // post dispatch hook
            hookMetadata // hook metadata
        );

        uint256 oldETHBal = users.alice.balance;

        // Broadcast x-chain messages
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        vm.expectCall({
            callee: address(rootIcaRouter),
            data: abi.encodeCall(
                IInterchainAccountRouter.callRemoteCommitReveal,
                (
                    leafDomain,
                    rootIcaRouter.routers(leafDomain),
                    bytes32(0),
                    hookMetadata,
                    IPostDispatchHook(address(rootIcaRouter.hook())),
                    TypeCasts.addressToBytes32(users.alice),
                    commitment
                )
            )
        });

        vm.expectEmit(address(router));
        emit Dispatcher.CrossChainSwap({
            caller: users.alice,
            localRouter: address(rootIcaRouter),
            destinationDomain: leafDomain,
            commitment: commitment
        });

        router.execute{value: MESSAGE_FEE * 2 + leftoverETH}(commands, inputs);

        assertEq(address(router).balance, 0);
        assertEq(address(rootIcaRouter).balance, 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
        // Assert excess fee was refunded
        assertEq(users.alice.balance, oldETHBal - (MESSAGE_FEE + leftoverETH));

        // Process Token Bridging message & check tokens arrived
        vm.selectFork(leafId);
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS),
            recipient: address(leafOpenUsdtTokenBridge)
        });
        leafMailbox.processNextInboundMessage();
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), amountIn);

        // Process Commitment message & check commitment was stored
        vm.expectEmit(address(leafMailbox));
        emit IMailbox.Process({
            origin: rootDomain,
            sender: TypeCasts.addressToBytes32(address(rootIcaRouter)),
            recipient: address(leafIcaRouter)
        });
        leafMailbox.processNextInboundMessage();
        assertTrue(OwnableMulticall(userICA).commitments(commitment));

        assertEq(ERC20(baseUSDC).balanceOf(users.alice), 0);

        // Self Relay the message & check swap was successful
        vm.expectEmit(address(leafRouter));
        emit Dispatcher.UniversalRouterSwap(userICA, users.alice);
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), 0); // no leftover input from swap in exactIn
        assertGt(ERC20(baseUSDC).balanceOf(users.alice), amountOutMin);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(userICA, address(leafRouter)), 0);
    }

    function test_executeCrosschainICARefund() public {
        uint256 amount = USDC_1;

        // Predict User's ICA address
        address payable userICA = payable(
            rootIcaRouter.getRemoteInterchainAccount({
                _destination: leafDomain,
                _owner: address(router),
                _userSalt: TypeCasts.addressToBytes32(users.alice)
            })
        );

        // Bridge tokens to User's ICA to simulate stuck funds
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            userICA,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            amount,
            MESSAGE_FEE,
            leafDomain,
            true
        );

        // Broadcast bridge message
        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amount);
        router.execute{value: MESSAGE_FEE}(commands, inputs);

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
        bytes32 commitment = hashCommitment({_calls: calls, _salt: TypeCasts.addressToBytes32(users.alice)});

        // Encode origin chain command
        commands = abi.encodePacked(bytes1(uint8(Commands.EXECUTE_CROSS_CHAIN)));
        inputs[0] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            bytes32(0), // destination ism
            commitment, // commitment of the calls to be made
            MESSAGE_FEE, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            new bytes(0) // hook metadata
        );
        router.execute{value: MESSAGE_FEE}(commands, inputs);

        // Process Commitment message & check commitment was stored
        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        assertTrue(OwnableMulticall(userICA).commitments(commitment));

        // Self Relay the message. Refund transfer should be executed
        vm.expectEmit(OPEN_USDT_ADDRESS);
        emit ERC20.Transfer({from: userICA, to: users.alice, amount: amount});
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});

        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), amount);
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(userICA), 0);
    }

    function test_RevertWhen_executeCrosschainInsufficientFee() public {
        uint256 amountIn = USDC_1;
        uint256 amountOutMin = 9e5;
        /// @dev Insufficient message fee
        uint256 msgFee = MESSAGE_FEE - 1;

        (,, bytes memory commands, bytes[] memory inputs) = _executeCrosschainParams({
            _amountIn: amountIn,
            _amountOutMin: amountOutMin,
            _msgFee: msgFee,
            _leftoverETH: 0
        });

        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        vm.expectRevert(); // OutOfFunds
        router.execute{value: MESSAGE_FEE}(commands, inputs);
    }

    function test_RevertWhen_executeCrosschainFeeGreaterThanContractBalance() public {
        uint256 amountIn = USDC_1;
        uint256 amountOutMin = 9e5;

        (,, bytes memory commands, bytes[] memory inputs) = _executeCrosschainParams({
            _amountIn: amountIn,
            _amountOutMin: amountOutMin,
            _msgFee: MESSAGE_FEE,
            _leftoverETH: 0
        });

        deal(OPEN_USDT_ADDRESS, users.alice, USDC_1);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        vm.expectRevert(); // OutOfFunds
        router.execute{value: MESSAGE_FEE}(commands, inputs); // @dev Fee only covers x-chain bridge command
    }

    function testGas_executeCrosschainOriginSuccess() public {
        uint256 amountIn = USDC_1;
        uint256 amountOutMin = 9e5;
        uint256 leftoverETH = MESSAGE_FEE / 2;

        (,, bytes memory commands, bytes[] memory inputs) = _executeCrosschainParams({
            _amountIn: amountIn,
            _amountOutMin: amountOutMin,
            _msgFee: MESSAGE_FEE,
            _leftoverETH: leftoverETH
        });

        deal(OPEN_USDT_ADDRESS, users.alice, amountIn);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute{value: MESSAGE_FEE * 2 + leftoverETH}(commands, inputs);
        vm.snapshotGasLastCall('UniversalRouter_ExecuteCrossChain_Origin_Success');
    }

    function testGas_executeCrosschainOriginFallback() public {
        uint256 amountIn = USDC_1;
        /// @dev Setting `amountOutMin` too large to simulate swap failure
        uint256 amountOutMin = amountIn * 10;
        uint256 leftoverETH = MESSAGE_FEE / 2;

        (,, bytes memory commands, bytes[] memory inputs) = _executeCrosschainParams({
            _amountIn: amountIn,
            _amountOutMin: amountOutMin,
            _msgFee: MESSAGE_FEE,
            _leftoverETH: leftoverETH
        });

        deal(OPEN_USDT_ADDRESS, users.alice, amountIn);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute{value: MESSAGE_FEE * 2 + leftoverETH}(commands, inputs);
        vm.snapshotGasLastCall('UniversalRouter_ExecuteCrossChain_Origin_Fallback');
    }

    function testGas_executeCrosschainDestinationSuccess() public {
        uint256 amountIn = USDC_1;
        uint256 amountOutMin = 9e5;
        uint256 leftoverETH = MESSAGE_FEE / 2;

        (address payable userICA, CallLib.Call[] memory calls, bytes memory commands, bytes[] memory inputs) =
        _executeCrosschainParams({
            _amountIn: amountIn,
            _amountOutMin: amountOutMin,
            _msgFee: MESSAGE_FEE,
            _leftoverETH: leftoverETH
        });

        deal(OPEN_USDT_ADDRESS, users.alice, amountIn);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute{value: MESSAGE_FEE * 2 + leftoverETH}(commands, inputs);

        // Process Token Bridging & Commitment messages
        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        leafMailbox.processNextInboundMessage();

        // Self Relay the message
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});
        vm.snapshotGasLastCall('UniversalRouter_ExecuteCrossChain_Destination_Success');
    }

    function testGas_executeCrosschainDestinationFallback() public {
        uint256 amountIn = USDC_1;
        /// @dev Setting `amountOutMin` too large to simulate swap failure
        uint256 amountOutMin = amountIn * 10;
        uint256 leftoverETH = MESSAGE_FEE / 2;

        (address payable userICA, CallLib.Call[] memory calls, bytes memory commands, bytes[] memory inputs) =
        _executeCrosschainParams({
            _amountIn: amountIn,
            _amountOutMin: amountOutMin,
            _msgFee: MESSAGE_FEE,
            _leftoverETH: leftoverETH
        });

        deal(OPEN_USDT_ADDRESS, users.alice, amountIn);
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), amountIn);
        router.execute{value: MESSAGE_FEE * 2 + leftoverETH}(commands, inputs);

        // Process Token Bridging & Commitment messages
        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();
        leafMailbox.processNextInboundMessage();

        // Self Relay the message
        vm.startPrank({msgSender: users.alice});
        OwnableMulticall(userICA).revealAndExecute({calls: calls, salt: TypeCasts.addressToBytes32(users.alice)});
        vm.snapshotGasLastCall('UniversalRouter_ExecuteCrossChain_Destination_Fallback');
    }

    /// @dev Helper to generate the parameters for valid execute x-chain calls
    function _executeCrosschainParams(uint256 _amountIn, uint256 _amountOutMin, uint256 _msgFee, uint256 _leftoverETH)
        internal
        view
        returns (address payable userICA, CallLib.Call[] memory calls, bytes memory commands, bytes[] memory inputs)
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
        bytes32 commitment = hashCommitment({_calls: calls, _salt: TypeCasts.addressToBytes32(users.alice)});

        // Predict User's ICA address
        userICA = payable(
            rootIcaRouter.getRemoteInterchainAccount({
                _destination: leafDomain,
                _owner: address(router),
                _userSalt: TypeCasts.addressToBytes32(users.alice)
            })
        );

        // Encode origin chain commands
        commands = abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)), bytes1(uint8(Commands.EXECUTE_CROSS_CHAIN)));
        inputs = new bytes[](2);
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            userICA,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            _amountIn,
            MESSAGE_FEE,
            leafDomain,
            true
        );
        bytes memory hookMetadata = StandardHookMetadata.formatMetadata({
            _msgValue: uint256(0),
            _gasLimit: HypXERC20(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS).destinationGas(rootDomain),
            _refundAddress: users.alice,
            _customMetadata: ''
        });
        inputs[1] = abi.encode(
            leafDomain, // destination domain
            address(rootIcaRouter), // origin ica router
            rootIcaRouter.routers(leafDomain), // destination ica router
            bytes32(0), // destination ism
            commitment, // commitment of the calls to be made
            _msgFee + _leftoverETH, // fee to dispatch x-chain message
            rootIcaRouter.hook(), // post dispatch hook
            hookMetadata // hook metadata
        );
    }

    function createAndSeedPair(address tokenA, address tokenB, bool _stable) internal returns (address newPair) {
        address factory = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
        newPair = IPoolFactory(factory).getPool(tokenA, tokenB, _stable);
        if (newPair == address(0)) {
            newPair = IPoolFactory(factory).createPool(tokenA, tokenB, _stable);
        }

        deal(tokenA, address(this), 100 * 10 ** ERC20(tokenA).decimals());
        deal(tokenB, address(this), 100 * 10 ** ERC20(tokenB).decimals());

        ERC20(tokenA).transfer(address(newPair), 100 * 10 ** ERC20(tokenA).decimals());
        ERC20(tokenB).transfer(address(newPair), 100 * 10 ** ERC20(tokenB).decimals());
        IPool(newPair).mint(address(this));
    }
}
