// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BridgeTypes} from '../../../../contracts/libraries/BridgeTypes.sol';
import {BridgeRouter} from '../../../../contracts/modules/bridge/BridgeRouter.sol';
import {Commands} from '../../../../contracts/libraries/Commands.sol';
import {IChainRegistry} from '../../../../contracts/interfaces/external/IChainRegistry.sol';
import './BaseOverrideBridge.sol';

contract BridgeTokenTest is BaseOverrideBridge {
    uint256 public openUsdtBridgeAmount = USDC_1 * 1000;
    uint256 public xVeloBridgeAmount = TOKEN_1 * 1000;

    uint256 mockDomainId = 111;

    bytes public commands = abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)));
    bytes[] public inputs;

    uint256 feeAmount = 0.1 ether;

    function setUp() public override {
        super.setUp();

        deal(address(users.alice), 1 ether);
        deal(OPEN_USDT_ADDRESS, users.alice, openUsdtBridgeAmount);
        deal(VELO_ADDRESS, users.alice, xVeloBridgeAmount);

        vm.selectFork(leafId_2);
        deal(XVELO_ADDRESS, users.alice, xVeloBridgeAmount);

        vm.selectFork(rootId);

        inputs = new bytes[](1);

        vm.startPrank({msgSender: users.alice});
    }

    function test_WhenRecipientIsZeroAddress() external {
        // It should revert with {InvalidRecipient}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            address(0), //recipient
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            leafDomain,
            true
        );

        vm.expectRevert(BridgeRouter.InvalidRecipient.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenMessageFeeIsSmallerThanContractBalance() external {
        // It should revert with {InvalidETH}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            leafDomain,
            true
        );

        ERC20(OPEN_USDT_ADDRESS).approve(address(router), type(uint256).max);
        vm.expectRevert(); // OutOfFunds
        router.execute{value: feeAmount - 1}(commands, inputs);
    }

    function test_RevertWhen_BridgeIsZeroAddress() external {
        // It should revert with {InvalidBridgeType}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            address(0), //bridge
            openUsdtBridgeAmount,
            feeAmount,
            leafDomain,
            true
        );

        vm.expectRevert();
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_RevertWhen_TokenIsZeroAddress() external {
        // It should revert
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            address(0),
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            leafDomain,
            true
        );

        vm.expectRevert(BridgeRouter.InvalidTokenAddress.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_RevertWhen_AmountIsZero() external {
        // It should revert
        // testing both bridge
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            0, // amount
            feeAmount,
            leafDomain,
            true
        );

        vm.expectRevert(bytes('MintLimits: replenish amount cannot be 0'));
        router.execute{value: feeAmount}(commands, inputs);

        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            0, // amount
            leafDomain_2,
            true
        );

        vm.expectRevert(ITokenBridge.ZeroAmount.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenBridgeTypeIsInvalid() external {
        // It should revert with {InvalidBridgeType}
        inputs[0] = abi.encode(
            0,
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            leafDomain,
            true
        );

        vm.expectRevert(abi.encodeWithSelector(BridgeRouter.InvalidBridgeType.selector, 0));
        router.execute{value: feeAmount}(commands, inputs);
    }

    modifier whenBasicValidationsPass() {
        _;
    }

    modifier whenBridgeTypeIsHYP_XERC20() {
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            leafDomain,
            true
        );

        // polled the value from TokenBridge Mailbox -> 105179722836615
        TestPostDispatchHook(address(rootMailbox.defaultHook())).setFee(105179722836615);
        _;
    }

    function test_WhenTokenIsNotTheBridgeToken() external whenBasicValidationsPass whenBridgeTypeIsHYP_XERC20 {
        // It should revert with {InvalidTokenAddress}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            leafDomain,
            true
        );

        vm.expectRevert(BridgeRouter.InvalidTokenAddress.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenNoTokenApprovalWasGiven() external whenBasicValidationsPass whenBridgeTypeIsHYP_XERC20 {
        // It should revert with {AllowanceExpired}

        vm.expectRevert(abi.encodeWithSelector(IAllowanceTransfer.AllowanceExpired.selector, 0));
        router.execute{value: feeAmount}(commands, inputs);
    }

    modifier whenUsingPermit2() {
        ERC20(OPEN_USDT_ADDRESS).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(OPEN_USDT_ADDRESS, address(router), type(uint160).max, type(uint48).max);
        _;
    }

    function test_WhenDomainIsZero() external whenBasicValidationsPass whenBridgeTypeIsHYP_XERC20 whenUsingPermit2 {
        // It should revert with "No router enrolled for domain: 0"
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            0,
            true
        );

        vm.expectRevert(bytes('No router enrolled for domain: 0'));
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsNotRegistered()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsHYP_XERC20
        whenUsingPermit2
    {
        // It should revert with "No router enrolled for domain: 111"
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            mockDomainId,
            true
        );

        vm.expectRevert(bytes('No router enrolled for domain: 111'));
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsTheSameAsSourceDomain()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsHYP_XERC20
        whenUsingPermit2
    {
        // It should revert with "No router enrolled for domain: 10"
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            rootDomain,
            true
        );

        vm.expectRevert(bytes('No router enrolled for domain: 10'));
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_RevertWhen_FeeIsInsufficient()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsHYP_XERC20
        whenUsingPermit2
    {
        // It should revert
        vm.expectRevert(); // OutOfFunds
        router.execute{value: 0}(commands, inputs);
    }

    function test_WhenAllChecksPass() external whenBasicValidationsPass whenBridgeTypeIsHYP_XERC20 whenUsingPermit2 {
        // It should bridge tokens to destination chain
        // It should return excess fee if any
        // It should emit {UniversalRouterBridge} event

        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(
            users.alice, users.alice, OPEN_USDT_ADDRESS, openUsdtBridgeAmount, leafDomain
        );
        router.execute{value: feeAmount}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertOUsdt();

        // Assert excess fee was refunded
        assertGt(balanceAfter, balanceBefore - feeAmount, 'Excess fee not refunded');
    }

    modifier whenUsingDirectApproval() {
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), type(uint256).max);
        _;
    }

    function test_WhenDomainIsZero_()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsHYP_XERC20
        whenUsingDirectApproval
    {
        // It should revert with "No router enrolled for domain: 0"
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            0,
            true
        );

        vm.expectRevert(bytes('No router enrolled for domain: 0'));
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsNotRegistered_()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsHYP_XERC20
        whenUsingDirectApproval
    {
        // It should revert with "No router enrolled for domain: 111"
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            mockDomainId,
            true
        );

        vm.expectRevert(bytes('No router enrolled for domain: 111'));
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsTheSameAsSourceDomain_()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsHYP_XERC20
        whenUsingDirectApproval
    {
        // It should revert with "No router enrolled for domain: 10"
        inputs[0] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount,
            rootDomain,
            true
        );

        vm.expectRevert(bytes('No router enrolled for domain: 10'));
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_RevertWhen_FeeIsInsufficient_()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsHYP_XERC20
        whenUsingDirectApproval
    {
        // It should revert
        vm.expectRevert(); // OutOfFunds
        router.execute{value: 0}(commands, inputs);
    }

    function test_WhenAllChecksPass_()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsHYP_XERC20
        whenUsingDirectApproval
    {
        // It should bridge tokens to destination chain
        // It should return excess fee if any
        // It should emit {UniversalRouterBridge} event

        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(
            users.alice, users.alice, OPEN_USDT_ADDRESS, openUsdtBridgeAmount, leafDomain
        );
        router.execute{value: feeAmount}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertOUsdt();

        // Assert excess fee was refunded
        assertGt(balanceAfter, balanceBefore - feeAmount, 'Excess fee not refunded');
    }

    modifier whenBridgeTypeIsXVELO() {
        _;
    }

    modifier whenDestinationChainIsMODE() {
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount,
            leafDomain_2,
            true
        );

        // polled the value from TokenBridge Mailbox -> 162482049456615
        TestPostDispatchHook(address(rootMailbox.defaultHook())).setFee(162482049456615);
        _;
    }

    function test_WhenTokenIsNotTheBridgeToken_()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
    {
        // It should revert with {InvalidTokenAddress}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            address(rootXVeloTokenBridge),
            1000, // openUSDT is 6 decimals so can't use xVeloBridgeAmount
            feeAmount,
            leafDomain_2,
            true
        );

        vm.expectRevert(BridgeRouter.InvalidTokenAddress.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenNoTokenApprovalWasGiven_()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
    {
        // It should revert with {AllowanceExpired}
        vm.expectRevert(abi.encodeWithSelector(IAllowanceTransfer.AllowanceExpired.selector, 0));
        router.execute{value: feeAmount}(commands, inputs);
    }

    modifier whenUsingPermit2_() {
        ERC20(VELO_ADDRESS).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(VELO_ADDRESS, address(router), type(uint160).max, type(uint48).max);
        _;
    }

    function test_WhenDomainIsZero__()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
        whenUsingPermit2_
    {
        // It should revert with {NotRegistered}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount,
            0,
            true
        );

        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsNotRegistered__()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
        whenUsingPermit2_
    {
        // It should revert with {NotRegistered}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount,
            mockDomainId,
            true
        );

        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsTheSameAsSourceDomain__()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
        whenUsingPermit2_
    {
        // It should revert with {NotRegistered}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount,
            rootDomain,
            true
        );

        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenFeeIsInsufficient__()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
        whenUsingPermit2_
    {
        // It should revert with "IGP: insufficient interchain gas payment"
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            0, // fee amount
            leafDomain_2,
            true
        );

        vm.expectRevert('IGP: insufficient interchain gas payment');
        router.execute{value: 0}(commands, inputs);
    }

    function test_WhenAllChecksPass__()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
        whenUsingPermit2_
    {
        // It should bridge tokens to destination chain
        // It should return excess fee if any
        // It should emit {UniversalRouterBridge} event

        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(users.alice, users.alice, VELO_ADDRESS, xVeloBridgeAmount, leafDomain_2);
        router.execute{value: feeAmount}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertXVelo();

        // Assert excess fee was refunded
        assertGt(balanceAfter, balanceBefore - feeAmount, 'Excess fee not refunded');
    }

    modifier whenUsingDirectApproval_() {
        ERC20(VELO_ADDRESS).approve(address(router), type(uint256).max);
        _;
    }

    function test_WhenDomainIsZero___()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
        whenUsingDirectApproval_
    {
        // It should revert with {NotRegistered}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount,
            0,
            true
        );

        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsNotRegistered___()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
        whenUsingDirectApproval_
    {
        // It should revert with {NotRegistered}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount,
            mockDomainId,
            true
        );

        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsTheSameAsSourceDomain___()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
        whenUsingDirectApproval_
    {
        // It should revert with {NotRegistered}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount,
            rootDomain,
            true
        );

        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenFeeIsInsufficient___()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
        whenUsingDirectApproval_
    {
        // It should revert with "IGP: insufficient interchain gas payment"
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            0, // fee amount
            leafDomain_2,
            true
        );

        vm.expectRevert('IGP: insufficient interchain gas payment');
        router.execute{value: 0}(commands, inputs);
    }

    function test_WhenAllChecksPass___()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMODE
        whenUsingDirectApproval_
    {
        // It should bridge tokens to destination chain
        // It should return excess fee if any
        // It should emit {UniversalRouterBridge} event
        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(users.alice, users.alice, VELO_ADDRESS, xVeloBridgeAmount, leafDomain_2);
        router.execute{value: feeAmount}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertXVelo();

        // Assert excess fee was refunded
        assertGt(balanceAfter, balanceBefore - feeAmount, 'Excess fee not refunded');
    }

    modifier whenDestinationChainIsOPTIMISM() {
        vm.selectFork(leafId_2);

        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            XVELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount,
            rootDomain,
            true
        );

        TestPostDispatchHook(address(leafMailbox_2.defaultHook())).setFee(111111111111111);
        _;
    }

    function test_WhenTokenIsNotTheBridgeToken__()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsOPTIMISM
    {
        // It should revert with {InvalidTokenAddress}
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            address(rootXVeloTokenBridge),
            1000, // openUSDT is 6 decimals so can't use xVeloBridgeAmount
            feeAmount,
            rootDomain,
            true
        );

        vm.expectRevert(BridgeRouter.InvalidTokenAddress.selector);
        leafRouter_2.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenNoTokenApprovalWasGiven__()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsOPTIMISM
    {
        // It should revert with {AllowanceExpired}
        vm.expectRevert(abi.encodeWithSelector(IAllowanceTransfer.AllowanceExpired.selector, 0));
        leafRouter_2.execute{value: feeAmount}(commands, inputs);
    }

    modifier whenUsingPermit2__() {
        ERC20(XVELO_ADDRESS).approve(address(MODE_PERMIT2), type(uint256).max);
        MODE_PERMIT2.approve(XVELO_ADDRESS, address(leafRouter_2), type(uint160).max, type(uint48).max);
        _;
    }

    function test_WhenFeeIsInsufficient____()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsOPTIMISM
        whenUsingPermit2__
    {
        // It should revert with "IGP: insufficient interchain gas payment"
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            XVELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            0, // fee amount
            rootDomain,
            true
        );

        vm.expectRevert('IGP: insufficient interchain gas payment');
        leafRouter_2.execute{value: 0}(commands, inputs);
    }

    function test_WhenAllChecksPass____()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsOPTIMISM
        whenUsingPermit2__
    {
        // It should bridge tokens to destination chain
        // It should return excess fee if any
        // It should emit {UniversalRouterBridge} event
        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(users.alice, users.alice, XVELO_ADDRESS, xVeloBridgeAmount, rootDomain);
        leafRouter_2.execute{value: feeAmount}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertXVelo();

        // Assert excess fee was refunded
        assertGt(balanceAfter, balanceBefore - feeAmount, 'Excess fee not refunded');
    }

    modifier whenUsingDirectApproval__() {
        ERC20(XVELO_ADDRESS).approve(address(leafRouter_2), type(uint256).max);
        _;
    }

    function test_WhenFeeIsInsufficient_____()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsOPTIMISM
        whenUsingDirectApproval__
    {
        // It should revert with "IGP: insufficient interchain gas payment"
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            XVELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            0, // fee amount
            rootDomain,
            true
        );

        vm.expectRevert('IGP: insufficient interchain gas payment');
        leafRouter_2.execute{value: 0}(commands, inputs);
    }

    function test_WhenAllChecksPass_____()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsOPTIMISM
        whenUsingDirectApproval__
    {
        // It should bridge tokens to destination chain
        // It should return excess fee if any
        // It should emit {UniversalRouterBridge} event
        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(leafRouter_2));
        emit Dispatcher.UniversalRouterBridge(users.alice, users.alice, XVELO_ADDRESS, xVeloBridgeAmount, rootDomain);
        leafRouter_2.execute{value: feeAmount}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertXVelo();

        // Assert excess fee was refunded
        assertGt(balanceAfter, balanceBefore - feeAmount, 'Excess fee not refunded');
    }

    function _assertOUsdt() private {
        // Verify token transfer occurred
        assertEq(ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice), 0, 'oUSDT balance should be 0 on root after bridge');

        vm.selectFork(leafId);
        leafMailbox.processNextInboundMessage();

        assertEq(
            ERC20(OPEN_USDT_ADDRESS).balanceOf(users.alice),
            openUsdtBridgeAmount,
            'oUSDT balance should be 1000 on leaf after bridge'
        );
    }

    function _assertXVelo() private {
        if (vm.activeFork() == rootId) {
            // Verify token transfer occurred
            assertEq(ERC20(VELO_ADDRESS).balanceOf(users.alice), 0, 'VELO balance should be 0 on root after bridge');

            vm.selectFork(leafId_2);
            leafMailbox_2.processNextInboundMessage();

            assertEq(
                ERC20(XVELO_ADDRESS).balanceOf(users.alice) - xVeloBridgeAmount, // we minted 1000 XVELO on leaf in the setup
                xVeloBridgeAmount,
                'XVELO balance should be 1000 on leaf after bridge'
            );
        } else {
            // Verify token transfer occurred
            assertEq(ERC20(XVELO_ADDRESS).balanceOf(users.alice), 0, 'XVELO balance should be 0 on leaf after bridge');

            vm.selectFork(rootId);
            rootMailbox.processNextInboundMessage();

            assertEq(
                ERC20(VELO_ADDRESS).balanceOf(users.alice) - xVeloBridgeAmount, // we minted 1000 VELO on root in the setup
                xVeloBridgeAmount,
                'VELO balance should be 1000 on root after bridge'
            );
        }
    }

    /// GAS CHECKS ///

    function testGas_HypXERC20BridgePermit2() public whenBridgeTypeIsHYP_XERC20 {
        ERC20(OPEN_USDT_ADDRESS).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(OPEN_USDT_ADDRESS, address(router), type(uint160).max, type(uint48).max);

        router.execute{value: feeAmount}(commands, inputs);
        vm.snapshotGasLastCall('BridgeRouter_HypXERC20_Permit2');
    }

    function testGas_HypXERC20BridgeDirectApproval() public whenBridgeTypeIsHYP_XERC20 {
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), type(uint256).max);

        router.execute{value: feeAmount}(commands, inputs);
        vm.snapshotGasLastCall('BridgeRouter_HypXERC20_DirectApproval');
    }

    function testGas_XVeloBridgePermit2() public whenBridgeTypeIsXVELO whenDestinationChainIsMODE {
        ERC20(VELO_ADDRESS).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(VELO_ADDRESS, address(router), type(uint160).max, type(uint48).max);

        router.execute{value: feeAmount}(commands, inputs);
        vm.snapshotGasLastCall('BridgeRouter_XVelo_Permit2');
    }

    function testGas_XVeloBridgeDirectApproval() public whenBridgeTypeIsXVELO whenDestinationChainIsMODE {
        ERC20(VELO_ADDRESS).approve(address(router), type(uint256).max);

        router.execute{value: feeAmount}(commands, inputs);
        vm.snapshotGasLastCall('BridgeRouter_XVelo_DirectApproval');
    }
}
