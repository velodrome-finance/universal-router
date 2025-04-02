// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import 'forge-std/Test.sol';
import {IXERC20} from '@hyperlane/core/contracts/token/interfaces/IXERC20.sol';
import {HypXERC20} from '@hyperlane/core/contracts/token/extensions/HypXERC20.sol';
import {TestIsm} from '@hyperlane/core/contracts/test/TestIsm.sol';
import {Dispatcher} from '../../contracts/base/Dispatcher.sol';
import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {CreateXLibrary} from '../../contracts/libraries/CreateXLibrary.sol';
import {Mailbox, MultichainMockMailbox} from '../foundry-tests/mock/MultichainMockMailbox.sol';
import {Users} from '../foundry-tests/utils/Users.sol';
import {TestDeployRoot, RouterParameters} from '../foundry-tests/utils/TestDeployRoot.sol';
import {
    TestConstants,
    IPermit2,
    ERC20,
    IUniswapV2Factory,
    IPoolFactory,
    VelodromeTimeLibrary
} from '../foundry-tests/utils/TestConstants.t.sol';

abstract contract BaseForkFixture is Test, TestConstants {
    UniversalRouter public router;

    TestDeployRoot public deployRoot;
    RouterParameters public params;

    // anything prefixed with root is deployed on the root chain
    // anything prefixed with leaf is deployed on the leaf chain
    // in the context of velodrome superchain, the root chain will always be optimism (chainid=10)
    // leaf chains will be any chain that velodrome expands to

    // root variables
    uint32 public root = 10; // root chain id
    uint32 public rootDomain = 10; // root domain
    uint256 public rootId; // root fork id (used by foundry)
    uint256 public rootStartTime; // root fork start time (set to start of epoch for simplicity)
    uint256 public rootForkBlockNumber = 133333333; // creation of oUSDT is at blk 132196375

    // root contracts
    IXERC20 public rootOpenUSDT = IXERC20(OPEN_USDT_ADDRESS);
    HypXERC20 public rootOpenUsdtTokenBridge;

    // root-only mocks
    MultichainMockMailbox public rootMailbox;
    TestIsm public rootIsm;

    // leaf variables
    uint32 public leaf = 8453; // leaf chain id
    uint32 public leafDomain = 8453; // leaf domain
    uint256 public leafId; // leaf fork id (used by foundry)
    uint256 public leafStartTime; // leaf fork start time (set to start of epoch for simplicity)
    uint256 public leafForkBlockNumber = 27777777; // creation of oUSDT is at blk 26601142

    // leaf contracts
    IXERC20 public leafOpenUSDT = IXERC20(OPEN_USDT_ADDRESS);
    HypXERC20 public leafOpenUsdtTokenBridge;

    // leaf-only mocks
    MultichainMockMailbox public leafMailbox;
    TestIsm public leafIsm;

    // common variables
    Users internal users;

    function setUp() public virtual {
        createUsers();

        setUpPreCommon();
        setUpRootChain();
        setUpLeafChain();
        setUpPostCommon();

        vm.selectFork({forkId: rootId});
    }

    function setUpPreCommon() public virtual {
        vm.startPrank(users.owner);
        rootId = vm.createSelectFork({urlOrAlias: 'optimism', blockNumber: rootForkBlockNumber});
        rootStartTime = block.timestamp;
        vm.warp({newTimestamp: rootStartTime});

        leafId = vm.createSelectFork({urlOrAlias: 'base', blockNumber: leafForkBlockNumber});
        leafStartTime = rootStartTime;
        vm.warp({newTimestamp: leafStartTime});

        vm.stopPrank();
    }

    function deployRootDependencies() public virtual {
        // deploy root mocks
        vm.startPrank(users.owner);
        rootMailbox = new MultichainMockMailbox(rootDomain);
        rootIsm = new TestIsm();

        vm.stopPrank();
    }

    function setUpRootChain() public virtual {
        vm.selectFork({forkId: rootId});
        deployRootDependencies();

        // deploy router
        params = RouterParameters({
            permit2: address(PERMIT2),
            weth9: address(WETH),
            v2Factory: address(UNI_V2_FACTORY),
            v3Factory: address(V3_FACTORY),
            pairInitCodeHash: bytes32(V2_INIT_CODE_HASH),
            poolInitCodeHash: bytes32(V3_INIT_CODE_HASH),
            v4PoolManager: address(0),
            v3NFTPositionManager: address(0),
            v4PositionManager: address(0),
            veloV2Factory: address(VELO_V2_FACTORY),
            veloCLFactory: address(CL_FACTORY),
            veloV2InitCodeHash: VELO_V2_INIT_CODE_HASH,
            veloCLInitCodeHash: CL_POOL_INIT_CODE_HASH
        });

        deployRoot = new TestDeployRoot(params);
        deployRoot.run();

        router = deployRoot.router();

        // deploy root contracts
        /// @dev some tests require lower block number to execute properly
        if (rootForkBlockNumber >= 132196376) {
            rootOpenUsdtTokenBridge = new HypXERC20(OPEN_USDT_ADDRESS, address(rootMailbox));
            vm.label({account: address(rootOpenUsdtTokenBridge), newLabel: 'Root OpenUSDT Token Bridge'});
            vm.label({account: address(rootOpenUSDT), newLabel: 'Root OpenUSDT'});
        }

        vm.label({account: address(router), newLabel: 'UniversalRouter'});
        vm.label({account: address(rootMailbox), newLabel: 'Root Mailbox'});
        vm.label({account: address(rootIsm), newLabel: 'Root ISM'});
    }

    function setUpLeafChain() public virtual {
        vm.selectFork({forkId: leafId});
        // deploy leaf mocks
        // use deployer2 here to ensure addresses are different from the root mocks
        // this helps with labeling
        vm.startPrank(users.deployer2);
        leafMailbox = new MultichainMockMailbox(leafDomain);
        leafIsm = new TestIsm();
        vm.stopPrank();

        leafOpenUsdtTokenBridge = new HypXERC20(OPEN_USDT_ADDRESS, address(leafMailbox));

        vm.label({account: address(leafMailbox), newLabel: 'Leaf Mailbox'});
        vm.label({account: address(leafIsm), newLabel: 'Leaf ISM'});
        vm.label({account: address(leafOpenUsdtTokenBridge), newLabel: 'Leaf OpenUSDT Token Bridge'});
        vm.label({account: address(leafOpenUSDT), newLabel: 'Leaf OpenUSDT'});
    }

    // Any set up required to link the contracts across the two chains
    function setUpPostCommon() public virtual {
        vm.selectFork({forkId: rootId});
        rootMailbox.addRemoteMailbox({_domain: leafDomain, _mailbox: leafMailbox});
        rootMailbox.setDomainForkId({_domain: leafDomain, _forkId: leafId});

        vm.selectFork({forkId: leafId});
        leafMailbox.addRemoteMailbox({_domain: rootDomain, _mailbox: rootMailbox});
        leafMailbox.setDomainForkId({_domain: rootDomain, _forkId: rootId});
    }

    function createUsers() internal {
        users = Users({
            owner: createUser('Owner'),
            alice: createUser('Alice'),
            bob: createUser('Bob'),
            charlie: createUser('Charlie'),
            deployer: createUser('Deployer'),
            deployer2: createUser('Deployer2')
        });
    }

    function createUser(string memory name) internal returns (address payable user) {
        user = payable(makeAddr({name: name}));
        vm.deal({account: user, newBalance: TOKEN_1 * 1_000});
    }

    /// @dev Move time forward on all chains
    function skipTime(uint256 _time) internal {
        uint256 activeFork = vm.activeFork();
        vm.selectFork({forkId: rootId});
        vm.warp({newTimestamp: block.timestamp + _time});
        vm.roll({newHeight: block.number + _time / 2});
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: block.timestamp + _time});
        vm.roll({newHeight: block.number + _time / 2});
        vm.selectFork({forkId: activeFork});
    }

    /// @dev Helper utility to forward time to next week on all chains
    ///      note epoch requires at least one second to have
    ///      passed into the new epoch
    function skipToNextEpoch(uint256 _offset) public {
        uint256 timeToNextEpoch = VelodromeTimeLibrary.epochNext(block.timestamp) - block.timestamp;
        skipTime(timeToNextEpoch + _offset);
    }

    modifier syncForkTimestamps() {
        uint256 fork = vm.activeFork();
        vm.selectFork({forkId: rootId});
        vm.warp({newTimestamp: rootStartTime});
        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});
        vm.selectFork({forkId: fork});
        _;
    }

    /// @dev Helper to get the InitCodeHash from the `_implementation` address
    function _getInitCodeHash(address _implementation) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                hex'3d602d80600a3d3981f3363d3d373d3d3d363d73', _implementation, hex'5af43d82803e903d91602b57fd5bf3'
            )
        );
    }
}
