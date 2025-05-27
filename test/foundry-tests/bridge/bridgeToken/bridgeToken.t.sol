// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BridgeTypes} from '../../../../contracts/libraries/BridgeTypes.sol';
import {BridgeRouter} from '../../../../contracts/modules/bridge/BridgeRouter.sol';
import {Commands} from '../../../../contracts/libraries/Commands.sol';
import {IDomainRegistry} from '../../../../contracts/interfaces/external/IDomainRegistry.sol';
import './BaseOverrideBridge.sol';

contract BridgeTokenTest is BaseOverrideBridge {
    uint256 public openUsdtBridgeAmount = USDC_1 * 1000;
    uint256 public xVeloBridgeAmount = TOKEN_1 * 1000;

    uint256 mockDomainId = 111;

    bytes public commands = abi.encodePacked(bytes1(uint8(Commands.BRIDGE_TOKEN)));
    bytes[] public inputs;

    /// @dev Fixed fee used for x-chain message quotes
    uint256 public constant MESSAGE_FEE = 1 ether / 10_000; // 0.0001 ETH
    uint256 leftoverETH = MESSAGE_FEE / 2;
    uint256 feeAmount = MESSAGE_FEE;

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
            feeAmount + leftoverETH,
            leafDomain,
            true
        );

        TestPostDispatchHook(address(rootMailbox.requiredHook())).setFee(MESSAGE_FEE);
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
        ERC20(OPEN_USDT_ADDRESS).approve(address(rootPermit2), type(uint256).max);
        rootPermit2.approve(OPEN_USDT_ADDRESS, address(router), type(uint160).max, type(uint48).max);
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
        // It should leave no dangling ERC20 approvals
        // It should emit {UniversalRouterBridge} event

        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(
            users.alice, users.alice, OPEN_USDT_ADDRESS, openUsdtBridgeAmount, leafDomain
        );
        router.execute{value: feeAmount + leftoverETH}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertOUsdt();

        // Assert excess fee was refunded
        assertEq(balanceAfter, balanceBefore - feeAmount, 'Excess fee not refunded');
        // Assert no dangling ERC20 approvals
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(address(router), address(rootPermit2)), 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(address(router), OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS), 0);
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
        // It should leave no dangling ERC20 approvals
        // It should emit {UniversalRouterBridge} event

        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(
            users.alice, users.alice, OPEN_USDT_ADDRESS, openUsdtBridgeAmount, leafDomain
        );
        router.execute{value: feeAmount + leftoverETH}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertOUsdt();

        // Assert excess fee was refunded
        assertEq(balanceAfter, balanceBefore - feeAmount, 'Excess fee not refunded');
        // Assert no dangling ERC20 approvals
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(address(router), address(rootPermit2)), 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(address(router), OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS), 0);
    }

    modifier whenBridgeTypeIsXVELO() {
        _;
    }

    modifier whenDestinationChainIsMETAL() {
        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount + leftoverETH,
            leafDomain_2,
            true
        );

        (, uint96 gasOverhead) = InterchainGasPaymaster(ROOT_IGP).destinationGasConfigs(leaf_2);
        uint256 gasLimit = rootXVeloTokenBridge.GAS_LIMIT() + gasOverhead;
        uint256 exchangeRate = 15000000000;
        uint256 tokenExchangeRate = 1e10;

        /// @dev Calculate gas price so that quote is `MESSAGE_FEE`
        uint256 requiredPrice = (MESSAGE_FEE * tokenExchangeRate) / (gasLimit * exchangeRate);

        // Mock the gas oracle response for domain 100001750
        bytes memory mockResponse = abi.encode(uint128(exchangeRate), uint128(requiredPrice));
        vm.mockCall(
            ROOT_STORAGE_GAS_ORACLE,
            abi.encodeWithSignature('getExchangeRateAndGasPrice(uint32)', leafDomain_2),
            mockResponse
        );
        _;
    }

    function test_WhenTokenIsNotTheBridgeToken_()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMETAL
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
        whenDestinationChainIsMETAL
    {
        // It should revert with {AllowanceExpired}
        vm.expectRevert(abi.encodeWithSelector(IAllowanceTransfer.AllowanceExpired.selector, 0));
        router.execute{value: feeAmount}(commands, inputs);
    }

    modifier whenUsingPermit2_() {
        ERC20(VELO_ADDRESS).approve(address(rootPermit2), type(uint256).max);
        rootPermit2.approve(VELO_ADDRESS, address(router), type(uint160).max, type(uint48).max);
        _;
    }

    function test_WhenDomainIsZero__()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMETAL
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

        vm.expectRevert(IDomainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsNotRegistered__()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMETAL
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

        vm.expectRevert(IDomainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsTheSameAsSourceDomain__()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMETAL
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

        vm.expectRevert(IDomainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenFeeIsInsufficient__()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMETAL
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
        whenDestinationChainIsMETAL
        whenUsingPermit2_
    {
        // It should bridge tokens to destination chain
        // It should return excess fee if any
        // It should leave no dangling ERC20 approvals
        // It should emit {UniversalRouterBridge} event

        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(users.alice, users.alice, VELO_ADDRESS, xVeloBridgeAmount, leafDomain_2);
        router.execute{value: feeAmount + leftoverETH}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertXVelo();

        // Assert excess fee was refunded
        // @dev Allow delta to account for rounding
        assertApproxEqAbs(balanceAfter, balanceBefore - feeAmount, 1e6, 'Excess fee not refunded');
        // Assert no dangling ERC20 approvals
        vm.selectFork({forkId: rootId});
        assertEq(ERC20(VELO_ADDRESS).allowance(address(router), address(rootPermit2)), 0);
        assertEq(ERC20(VELO_ADDRESS).allowance(address(router), address(rootXVeloTokenBridge)), 0);
    }

    modifier whenUsingDirectApproval_() {
        ERC20(VELO_ADDRESS).approve(address(router), type(uint256).max);
        _;
    }

    function test_WhenDomainIsZero___()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMETAL
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

        vm.expectRevert(IDomainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsNotRegistered___()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMETAL
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

        vm.expectRevert(IDomainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenDomainIsTheSameAsSourceDomain___()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMETAL
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

        vm.expectRevert(IDomainRegistry.NotRegistered.selector);
        router.execute{value: feeAmount}(commands, inputs);
    }

    function test_WhenFeeIsInsufficient___()
        external
        whenBasicValidationsPass
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMETAL
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
        whenDestinationChainIsMETAL
        whenUsingDirectApproval_
    {
        // It should bridge tokens to destination chain
        // It should return excess fee if any
        // It should leave no dangling ERC20 approvals
        // It should emit {UniversalRouterBridge} event
        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(users.alice, users.alice, VELO_ADDRESS, xVeloBridgeAmount, leafDomain_2);
        router.execute{value: feeAmount + leftoverETH}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertXVelo();

        // Assert excess fee was refunded
        // @dev Allow delta to account for rounding
        assertApproxEqAbs(balanceAfter, balanceBefore - feeAmount, 1e6, 'Excess fee not refunded');
        // Assert no dangling ERC20 approvals
        vm.selectFork({forkId: rootId});
        assertEq(ERC20(VELO_ADDRESS).allowance(address(router), address(rootPermit2)), 0);
        assertEq(ERC20(VELO_ADDRESS).allowance(address(router), address(rootXVeloTokenBridge)), 0);
    }

    modifier whenDestinationChainIsOPTIMISM() {
        vm.selectFork(leafId_2);

        inputs[0] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            XVELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount + leftoverETH,
            rootDomain,
            true
        );

        (, uint96 gasOverhead) = InterchainGasPaymaster(LEAF_IGP_2).destinationGasConfigs(rootDomain);
        uint256 gasLimit = leafXVeloTokenBridge.GAS_LIMIT() + gasOverhead;
        uint256 exchangeRate = 15000000000;
        uint256 tokenExchangeRate = 1e10;

        /// @dev Calculate gas price so that quote is `MESSAGE_FEE`
        uint256 requiredPrice = (MESSAGE_FEE * tokenExchangeRate) / (gasLimit * exchangeRate);

        // Mock the gas oracle response for domain 10
        bytes memory mockResponse = abi.encode(uint128(exchangeRate), uint128(requiredPrice));
        vm.mockCall(
            LEAF_STORAGE_GAS_ORACLE,
            abi.encodeWithSignature('getExchangeRateAndGasPrice(uint32)', rootDomain),
            mockResponse
        );
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
        ERC20(XVELO_ADDRESS).approve(address(leafPermit2_2), type(uint256).max);
        leafPermit2_2.approve(XVELO_ADDRESS, address(leafRouter_2), type(uint160).max, type(uint48).max);
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
        // It should leave no dangling ERC20 approvals
        // It should emit {UniversalRouterBridge} event
        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(users.alice, users.alice, XVELO_ADDRESS, xVeloBridgeAmount, rootDomain);
        leafRouter_2.execute{value: feeAmount + leftoverETH}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertXVelo();

        // Assert excess fee was refunded
        // @dev Allow delta to account for rounding
        assertApproxEqAbs(balanceAfter, balanceBefore - feeAmount, 1e6, 'Excess fee not refunded');
        // Assert no dangling ERC20 approvals
        vm.selectFork({forkId: leafId_2});
        assertEq(ERC20(XVELO_ADDRESS).allowance(address(leafRouter_2), address(leafPermit2_2)), 0);
        assertEq(ERC20(XVELO_ADDRESS).allowance(address(leafRouter_2), address(leafXVeloTokenBridge)), 0);
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
        // It should leave no dangling ERC20 approvals
        // It should emit {UniversalRouterBridge} event
        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(address(leafRouter_2));
        emit Dispatcher.UniversalRouterBridge(users.alice, users.alice, XVELO_ADDRESS, xVeloBridgeAmount, rootDomain);
        leafRouter_2.execute{value: feeAmount + leftoverETH}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertXVelo();

        // Assert excess fee was refunded
        // @dev Allow delta to account for rounding
        assertApproxEqAbs(balanceAfter, balanceBefore - feeAmount, 1e6, 'Excess fee not refunded');
        // Assert no dangling ERC20 approvals
        vm.selectFork({forkId: leafId_2});
        assertEq(ERC20(XVELO_ADDRESS).allowance(address(leafRouter_2), address(leafPermit2_2)), 0);
        assertEq(ERC20(XVELO_ADDRESS).allowance(address(leafRouter_2), address(leafXVeloTokenBridge)), 0);
    }

    function test_HypXERC20ChainedBridgeTokenFlow() external whenBridgeTypeIsHYP_XERC20 whenUsingDirectApproval {
        // Encode chained bridge command after transferFrom, so that payer is Router
        commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)), bytes1(uint8(Commands.BRIDGE_TOKEN)));
        inputs = new bytes[](2);
        inputs[0] = abi.encode(OPEN_USDT_ADDRESS, address(router), openUsdtBridgeAmount);
        inputs[1] = abi.encode(
            uint8(BridgeTypes.HYP_XERC20),
            ActionConstants.MSG_SENDER,
            OPEN_USDT_ADDRESS,
            OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS,
            openUsdtBridgeAmount,
            feeAmount + leftoverETH,
            leafDomain,
            false // payer is router
        );

        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(OPEN_USDT_ADDRESS);
        emit ERC20.Transfer(users.alice, address(router), openUsdtBridgeAmount);
        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(
            users.alice, users.alice, OPEN_USDT_ADDRESS, openUsdtBridgeAmount, leafDomain
        );
        router.execute{value: feeAmount + leftoverETH}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertOUsdt();

        // Assert excess fee was refunded
        assertEq(balanceAfter, balanceBefore - feeAmount, 'Excess fee not refunded');
        // Assert no dangling ERC20 approvals
        vm.selectFork({forkId: rootId});
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(address(router), address(rootPermit2)), 0);
        assertEq(ERC20(OPEN_USDT_ADDRESS).allowance(address(router), OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS), 0);
    }

    function test_VeloChainedBridgeTokenFlow()
        external
        whenBridgeTypeIsXVELO
        whenDestinationChainIsMETAL
        whenUsingDirectApproval_
    {
        // Encode chained bridge command after transferFrom, so that payer is Router
        commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)), bytes1(uint8(Commands.BRIDGE_TOKEN)));
        inputs = new bytes[](2);
        inputs[0] = abi.encode(VELO_ADDRESS, address(router), xVeloBridgeAmount);
        inputs[1] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            VELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount + leftoverETH,
            leafDomain_2,
            false // payer is router
        );

        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(VELO_ADDRESS);
        emit ERC20.Transfer(users.alice, address(router), xVeloBridgeAmount);
        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(users.alice, users.alice, VELO_ADDRESS, xVeloBridgeAmount, leafDomain_2);
        router.execute{value: feeAmount + leftoverETH}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertXVelo();

        // Assert excess fee was refunded
        // @dev Allow delta to account for rounding
        assertApproxEqAbs(balanceAfter, balanceBefore - feeAmount, 1e6, 'Excess fee not refunded');
        // Assert no dangling ERC20 approvals
        vm.selectFork({forkId: rootId});
        assertEq(ERC20(VELO_ADDRESS).allowance(address(router), address(rootPermit2)), 0);
        assertEq(ERC20(VELO_ADDRESS).allowance(address(router), address(rootXVeloTokenBridge)), 0);
    }

    function test_xVeloChainedBridgeTokenFlow()
        external
        whenBridgeTypeIsXVELO
        whenDestinationChainIsOPTIMISM
        whenUsingDirectApproval__
    {
        // Encode chained bridge command after transferFrom, so that payer is Router
        commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)), bytes1(uint8(Commands.BRIDGE_TOKEN)));
        inputs = new bytes[](2);
        inputs[0] = abi.encode(XVELO_ADDRESS, address(leafRouter_2), xVeloBridgeAmount);
        inputs[1] = abi.encode(
            uint8(BridgeTypes.XVELO),
            ActionConstants.MSG_SENDER,
            XVELO_ADDRESS,
            address(rootXVeloTokenBridge),
            xVeloBridgeAmount,
            feeAmount + leftoverETH,
            rootDomain,
            false // payer is router
        );

        uint256 balanceBefore = address(users.alice).balance;

        vm.expectEmit(XVELO_ADDRESS);
        emit ERC20.Transfer(users.alice, address(leafRouter_2), xVeloBridgeAmount);
        vm.expectEmit(address(router));
        emit Dispatcher.UniversalRouterBridge(users.alice, users.alice, XVELO_ADDRESS, xVeloBridgeAmount, rootDomain);
        leafRouter_2.execute{value: feeAmount + leftoverETH}(commands, inputs);

        uint256 balanceAfter = address(users.alice).balance;

        _assertXVelo();

        // Assert excess fee was refunded
        // @dev Allow delta to account for rounding
        assertApproxEqAbs(balanceAfter, balanceBefore - feeAmount, 1e6, 'Excess fee not refunded');
        // Assert no dangling ERC20 approvals
        vm.selectFork({forkId: leafId_2});
        assertEq(ERC20(XVELO_ADDRESS).allowance(address(leafRouter_2), address(leafPermit2_2)), 0);
        assertEq(ERC20(XVELO_ADDRESS).allowance(address(leafRouter_2), address(leafXVeloTokenBridge)), 0);
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
        ERC20(OPEN_USDT_ADDRESS).approve(address(rootPermit2), type(uint256).max);
        rootPermit2.approve(OPEN_USDT_ADDRESS, address(router), type(uint160).max, type(uint48).max);

        router.execute{value: feeAmount + leftoverETH}(commands, inputs);
        vm.snapshotGasLastCall('BridgeRouter_HypXERC20_Permit2');
    }

    function testGas_HypXERC20BridgeDirectApproval() public whenBridgeTypeIsHYP_XERC20 {
        ERC20(OPEN_USDT_ADDRESS).approve(address(router), type(uint256).max);

        router.execute{value: feeAmount + leftoverETH}(commands, inputs);
        vm.snapshotGasLastCall('BridgeRouter_HypXERC20_DirectApproval');
    }

    function testGas_XVeloBridgePermit2() public whenBridgeTypeIsXVELO whenDestinationChainIsMETAL {
        ERC20(VELO_ADDRESS).approve(address(rootPermit2), type(uint256).max);
        rootPermit2.approve(VELO_ADDRESS, address(router), type(uint160).max, type(uint48).max);

        router.execute{value: feeAmount + leftoverETH}(commands, inputs);
        vm.snapshotGasLastCall('BridgeRouter_XVelo_Permit2');
    }

    function testGas_XVeloBridgeDirectApproval() public whenBridgeTypeIsXVELO whenDestinationChainIsMETAL {
        ERC20(VELO_ADDRESS).approve(address(router), type(uint256).max);

        router.execute{value: feeAmount + leftoverETH}(commands, inputs);
        vm.snapshotGasLastCall('BridgeRouter_XVelo_DirectApproval');
    }
}
