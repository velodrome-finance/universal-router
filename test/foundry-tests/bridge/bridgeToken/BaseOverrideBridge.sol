// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {RootEscrowTokenBridge} from '../../../foundry-tests/mock/MockRootXVeloBridge.sol';
import {LeafEscrowTokenBridge} from '../../../foundry-tests/mock/MockLeafXVeloBridge.sol';
import './../../BaseForkFixture.t.sol';
import {ITokenBridge} from '../../../../contracts/interfaces/external/ITokenBridge.sol';
import {InterchainGasPaymaster} from '@hyperlane/core/contracts/hooks/igp/InterchainGasPaymaster.sol';
import {IGasOracle} from '@hyperlane/core/contracts/interfaces/IGasOracle.sol';

abstract contract BaseOverrideBridge is BaseForkFixture {
    using SafeCast for uint256;

    uint128 public rps; // rate limit per second
    uint128 public constant MAX_RATE_LIMIT_PER_SECOND = 25_000 * 1e18;

    function setUpPreCommon() public virtual override {
        vm.startPrank(users.owner);
        rootId = vm.createSelectFork({urlOrAlias: 'optimism', blockNumber: rootForkBlockNumber});
        rootStartTime = block.timestamp;
        weth = IWETH9(WETH9_ADDRESS);
        vm.warp({newTimestamp: rootStartTime});

        leafId = vm.createSelectFork({urlOrAlias: 'base', blockNumber: leafForkBlockNumber});
        leafStartTime = rootStartTime;
        weth = IWETH9(WETH9_ADDRESS);
        vm.warp({newTimestamp: leafStartTime});

        leafId_2 = vm.createSelectFork({urlOrAlias: 'metal', blockNumber: leafForkBlockNumber_2});
        leafStartTime_2 = rootStartTime;
        vm.warp({newTimestamp: leafStartTime_2});

        vm.stopPrank();
    }

    function setUp() public virtual override {
        leaf_2 = 1750; // metal chain id
        leafDomain_2 = 1000001750; // metal domain
        leafForkBlockNumber_2 = 18047714;

        leafPermit2 = METAL_PERMIT2_ADDRESS;
        leafMailboxAddress_2 = XVELO_METAL_MAILBOX_ADDRESS;

        super.setUp();

        vm.selectFork({forkId: rootId});

        // Deploy on root chain with deterministic address
        vm.startPrank(users.deployer);
        rootXVeloTokenBridge = ITokenBridge(
            address(
                new RootEscrowTokenBridge(
                    users.owner,
                    address(rootXVelo),
                    address(rootMailbox),
                    VOTING_ESCROW,
                    address(0), // paymaster
                    address(rootXVeloTokenBridge.securityModule())
                )
            )
        );

        vm.startPrank(users.owner);
        rootXVeloTokenBridge.registerDomain(leafDomain_2);
        rootXVeloTokenBridge.setHook({_hook: ROOT_IGP});

        // Configure root bridge with maximum buffer cap - use the token's actual owner
        address rootTokenOwner = Ownable(address(rootXVelo)).owner();
        vm.startPrank(rootTokenOwner);
        uint96 rootBufferCap = 1_000_000 * 1e18;
        rps = SafeCast.toUint128(rootBufferCap / DAY);
        rootXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bufferCap: rootBufferCap,
                bridge: address(rootXVeloTokenBridge),
                rateLimitPerSecond: rps
            })
        );
        vm.stopPrank();

        // Switch to leaf chain
        vm.selectFork({forkId: leafId_2});

        // Deploy on leaf chain with same deployer to get same address
        vm.startPrank(users.deployer);
        leafXVeloTokenBridge = ITokenBridge(
            address(
                new LeafEscrowTokenBridge(
                    users.owner,
                    address(leafXVelo),
                    address(leafMailbox_2),
                    address(leafXVeloTokenBridge.securityModule())
                )
            )
        );

        vm.startPrank(users.owner);
        leafXVeloTokenBridge.registerDomain(rootDomain);
        leafXVeloTokenBridge.setHook({_hook: LEAF_IGP_2});

        // Configure leaf bridge with maximum buffer cap - use the token's actual owner
        address leafTokenOwner = Ownable(address(leafXVelo)).owner();
        vm.startPrank(leafTokenOwner);
        uint96 leafBufferCap = 1_000_000 * 1e18;
        rps = SafeCast.toUint128(leafBufferCap / DAY);
        leafXVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bufferCap: leafBufferCap,
                bridge: address(leafXVeloTokenBridge),
                rateLimitPerSecond: rps
            })
        );
        vm.stopPrank();

        // Return to root chain
        vm.selectFork({forkId: rootId});
    }
}
