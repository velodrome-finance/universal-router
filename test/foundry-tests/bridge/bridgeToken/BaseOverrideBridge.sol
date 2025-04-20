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

    function setUp() public virtual override {
        super.setUp();

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

        /// As we are using a custom domain id for mode, one that is not supported on the fork
        /// We must manually set up the gas oracle config for the domain
        /// The config has been copied across from the original mode config, with the gas oracle call
        /// mocked to return a fixed value
        vm.startPrank(Ownable(ROOT_IGP).owner());
        // Get gas oracle config from hook for chain ID 34443
        (IGasOracle gasOracle, uint96 gasOverhead) = InterchainGasPaymaster(ROOT_IGP).destinationGasConfigs(leaf_2);

        // Set the same config for domain 1000034443
        InterchainGasPaymaster.GasParam[] memory configs = new InterchainGasPaymaster.GasParam[](1);
        configs[0] = InterchainGasPaymaster.GasParam({
            remoteDomain: leafDomain_2,
            config: InterchainGasPaymaster.DomainGasConfig({gasOracle: gasOracle, gasOverhead: gasOverhead})
        });
        InterchainGasPaymaster(ROOT_IGP).setDestinationGasConfigs(configs);

        // Mock the gas oracle response for domain 1000034443
        bytes memory mockResponse = abi.encode(uint128(15000000000), uint128(313141588));
        vm.mockCall(
            ROOT_STORAGE_GAS_ORACLE,
            abi.encodeWithSignature('getExchangeRateAndGasPrice(uint32)', leafDomain_2),
            mockResponse
        );

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
        leafXVeloTokenBridge.setHook({_hook: LEAF_IGP});

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
