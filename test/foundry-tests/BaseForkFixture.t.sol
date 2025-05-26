// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import 'forge-std/Test.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {CallLib} from '@hyperlane-updated/contracts/middleware/libs/Call.sol';
import {HypXERC20} from '@hyperlane/core/contracts/token/extensions/HypXERC20.sol';
import {TestIsm} from '@hyperlane/core/contracts/test/TestIsm.sol';
import {TestPostDispatchHook} from '@hyperlane/core/contracts/test/TestPostDispatchHook.sol';
import {IMailbox} from '@hyperlane/core/contracts/interfaces/IMailbox.sol';
import {IAllowanceTransfer} from 'permit2/src/interfaces/IAllowanceTransfer.sol';
import {IWETH9} from '@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol';

import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {Dispatcher} from '../../contracts/base/Dispatcher.sol';
import {Payments} from '../../contracts/modules/Payments.sol';
import {CreateXLibrary} from '../../contracts/libraries/CreateXLibrary.sol';
import {ITokenBridge} from '../../contracts/interfaces/external/ITokenBridge.sol';
import {IRootHLMessageModule} from '../../contracts/interfaces/external/IRootHLMessageModule.sol';
import {Constants} from '../../contracts/libraries/Constants.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';

import {Mailbox, MultichainMockMailbox} from '../foundry-tests/mock/MultichainMockMailbox.sol';
import {Users} from '../foundry-tests/utils/Users.sol';
import {TestDeployRouter, RouterParameters} from '../foundry-tests/utils/TestDeployRouter.sol';
import {IXERC20, MintLimits} from '../foundry-tests/mock/XERC20/IXERC20.sol';
import {IPool} from 'contracts/interfaces/external/IPool.sol';
import {
    TestConstants, IPermit2, ERC20, IUniswapV2Factory, IPoolFactory
} from '../foundry-tests/utils/TestConstants.t.sol';

abstract contract BaseForkFixture is Test, TestConstants {
    using SafeCast for uint256;

    TestDeployRouter public deployRouter;
    RouterParameters public params;

    // anything prefixed with root is deployed on the root chain
    // anything prefixed with leaf is deployed on the leaf chain
    // in the context of velodrome superchain, the root chain will always be optimism (chainid=10)
    // leaf chains will be any chain that velodrome expands to

    /// OPTIMISM ///
    // root variables
    uint32 public root = 10; // root chain id
    uint32 public rootDomain = 10; // root domain
    uint256 public rootId; // root fork id (used by foundry)
    uint256 public rootStartTime; // root fork start time (set to start of epoch for simplicity)
    uint256 public rootForkBlockNumber = 133333333; // creation of oUSDT is at blk 132196375

    // root router
    UniversalRouter public router;

    // root contracts
    IXERC20 public rootOpenUSDT = IXERC20(OPEN_USDT_ADDRESS);
    HypXERC20 public rootOpenUsdtTokenBridge = HypXERC20(OPEN_USDT_OPTIMISM_BRIDGE_ADDRESS);

    IXERC20 public rootXVelo = IXERC20(XVELO_ADDRESS);
    ITokenBridge public rootXVeloTokenBridge = ITokenBridge(XVELO_TOKEN_BRIDGE_ADDRESS);

    // root-only mocks
    MultichainMockMailbox public rootMailbox;

    /// BASE ///
    // leaf variables
    uint32 public leaf = 8453; // leaf chain id
    uint32 public leafDomain = 8453; // leaf domain
    uint256 public leafId; // leaf fork id (used by foundry)
    uint256 public leafStartTime; // leaf fork start time (set to start of epoch for simplicity)
    uint256 public leafForkBlockNumber = 28700000; // creation of oUSDT is at blk 26601142

    // leaf router
    UniversalRouter public leafRouter;

    // leaf contracts
    IXERC20 public leafOpenUSDT = IXERC20(OPEN_USDT_ADDRESS);
    HypXERC20 public leafOpenUsdtTokenBridge = HypXERC20(OPEN_USDT_BASE_BRIDGE_ADDRESS);
    // leaf-only mocks
    MultichainMockMailbox public leafMailbox;

    /// MODE ///
    // leaf variables
    uint32 public leaf_2 = 34443; // leaf chain id
    uint32 public leafDomain_2 = 1000034443; // leaf domain
    uint256 public leafId_2; // leaf fork id (used by foundry)
    uint256 public leafStartTime_2; // leaf fork start time (set to start of epoch for simplicity)
    uint256 public leafForkBlockNumber_2 = 21111111;

    // leaf deployment variables
    // values copied from DeployMode.s.sol
    address public leafPermit2 = MODE_PERMIT2_ADDRESS;
    address public leafVeloV2Factory = 0x31832f2a97Fd20664D76Cc421207669b55CE4BC0;
    address public leafVeloCLFactory = 0x04625B046C69577EfC40e6c0Bb83CDBAfab5a55F;
    bytes32 public leafVeloV2InitCodeHash = 0x558be7ee0c63546b31d0773eee1d90451bd76a0167bb89653722a2bd677c002d;
    bytes32 public leafVeloCLInitCodeHash = 0x7b216153c50849f664871825fa6f22b3356cdce2436e4f48734ae2a926a4c7e5;
    address public leafMailboxAddress_2 = XVELO_MODE_MAILBOX_ADDRESS;

    // leaf router
    UniversalRouter public leafRouter_2;

    // leaf contracts
    IXERC20 public leafXVelo = IXERC20(XVELO_ADDRESS);
    ITokenBridge public leafXVeloTokenBridge = ITokenBridge(XVELO_TOKEN_BRIDGE_ADDRESS);
    // leaf-only mocks
    MultichainMockMailbox public leafMailbox_2;

    // common variables
    Users internal users;
    IWETH9 public weth;

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
        weth = IWETH9(WETH9_ADDRESS);
        vm.warp({newTimestamp: rootStartTime});

        leafId = vm.createSelectFork({urlOrAlias: 'base', blockNumber: leafForkBlockNumber});
        leafStartTime = rootStartTime;
        weth = IWETH9(WETH9_ADDRESS);
        vm.warp({newTimestamp: leafStartTime});

        leafId_2 = vm.createSelectFork({urlOrAlias: 'mode', blockNumber: leafForkBlockNumber_2});
        leafStartTime_2 = rootStartTime;
        vm.warp({newTimestamp: leafStartTime_2});

        vm.stopPrank();
    }

    function deployRootDependencies() public virtual {
        // deploy root mocks
        rootMailbox = _overwriteMailbox(OPEN_USDT_OPTIMISM_MAILBOX_ADDRESS, OPEN_USDT_OPTIMISM_ISM_ADDRESS, rootDomain);
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
            veloV2Factory: address(VELO_V2_FACTORY),
            veloCLFactory: address(CL_FACTORY),
            veloV2InitCodeHash: VELO_V2_INIT_CODE_HASH,
            veloCLInitCodeHash: CL_POOL_INIT_CODE_HASH
        });

        deployRouter = new TestDeployRouter(params);
        deployRouter.run();

        router = deployRouter.router();

        // deploy root contracts
        /// @dev some tests require lower block number to execute properly
        if (rootForkBlockNumber >= 132196376) {
            vm.label({account: address(rootOpenUsdtTokenBridge), newLabel: 'Root OpenUSDT Token Bridge'});
            vm.label({account: address(rootOpenUSDT), newLabel: 'OpenUSDT'}); // same on op and base
        }

        vm.label({account: address(router), newLabel: 'UniversalRouter'});
        vm.label({account: address(rootMailbox), newLabel: 'Optimism Mailbox'});
        vm.label({account: address(rootXVeloTokenBridge), newLabel: 'XVELO Token Bridge'});
        vm.label({account: address(rootXVelo), newLabel: 'XVELO'}); // same on op and mode
        vm.label({account: address(VELO_ADDRESS), newLabel: 'VELO'});
    }

    function setUpLeafChain() public virtual {
        vm.selectFork({forkId: leafId});

        leafMailbox = _overwriteMailbox(OPEN_USDT_BASE_MAILBOX_ADDRESS, OPEN_USDT_BASE_ISM_ADDRESS, leafDomain);

        // deploy router on base
        params = RouterParameters({
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth9: address(WETH),
            v2Factory: 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6,
            v3Factory: 0x33128a8fC17869897dcE68Ed026d694621f6FDfD,
            pairInitCodeHash: 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f,
            poolInitCodeHash: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54,
            v4PoolManager: address(0),
            veloV2Factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da,
            veloCLFactory: 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A,
            veloV2InitCodeHash: 0x6f178972b07752b522a4da1c5b71af6524e8b0bd6027ccb29e5312b0e5bcdc3c,
            veloCLInitCodeHash: 0xffb9af9ea6d9e39da47392ecc7055277b9915b8bfc9f83f105821b7791a6ae30
        });

        deployRouter = new TestDeployRouter(params);
        deployRouter.run();

        leafRouter = deployRouter.router();

        vm.selectFork({forkId: leafId_2});

        // deploy router on mode (values copied from DeployMode.s.sol)
        params = RouterParameters({
            permit2: leafPermit2,
            weth9: address(WETH),
            v2Factory: address(0),
            v3Factory: address(0),
            pairInitCodeHash: bytes32(0),
            poolInitCodeHash: bytes32(0),
            v4PoolManager: address(0),
            veloV2Factory: leafVeloV2Factory,
            veloCLFactory: leafVeloCLFactory,
            veloV2InitCodeHash: leafVeloV2InitCodeHash,
            veloCLInitCodeHash: leafVeloCLInitCodeHash
        });

        deployRouter = new TestDeployRouter(params);
        deployRouter.run();

        leafRouter_2 = deployRouter.router();

        leafMailbox_2 = _overwriteMailbox(leafMailboxAddress_2, address(0), leafDomain_2);

        vm.label({account: address(leafMailbox), newLabel: 'Base Mailbox'});
        vm.label({account: address(leafOpenUsdtTokenBridge), newLabel: 'Leaf OpenUSDT Token Bridge'});
        vm.label({account: address(leafOpenUSDT), newLabel: 'OpenUSDT'}); // same on op and base
        vm.label({account: address(leafMailbox_2), newLabel: 'Mode Mailbox'});
    }

    // Any set up required to link the contracts across the two chains
    function setUpPostCommon() public virtual {
        if (rootForkBlockNumber < 132196376) return;
        vm.selectFork({forkId: rootId});

        // add base
        rootMailbox.addRemoteMailbox({_domain: leafDomain, _mailbox: leafMailbox});
        rootMailbox.setDomainForkId({_domain: leafDomain, _forkId: leafId});

        // for HypXERC20
        vm.prank(rootOpenUsdtTokenBridge.owner());
        rootOpenUsdtTokenBridge.enrollRemoteRouter({
            _domain: leafDomain,
            _router: _addressToBytes32(address(leafOpenUsdtTokenBridge))
        });

        rootMailbox.addRemoteMailbox({_domain: leafDomain_2, _mailbox: leafMailbox_2});
        rootMailbox.setDomainForkId({_domain: leafDomain_2, _forkId: leafId_2});

        vm.selectFork({forkId: leafId});

        // add optimism to base mailbox
        leafMailbox.addRemoteMailbox({_domain: rootDomain, _mailbox: rootMailbox});
        leafMailbox.setDomainForkId({_domain: rootDomain, _forkId: rootId});

        // for HypXERC20
        vm.prank(leafOpenUsdtTokenBridge.owner());
        leafOpenUsdtTokenBridge.enrollRemoteRouter({
            _domain: rootDomain,
            _router: _addressToBytes32(address(rootOpenUsdtTokenBridge))
        });

        vm.selectFork({forkId: leafId_2});
        // add optimism to mode mailbox
        leafMailbox_2.addRemoteMailbox({_domain: rootDomain, _mailbox: rootMailbox});
        leafMailbox_2.setDomainForkId({_domain: rootDomain, _forkId: rootId});

        vm.stopPrank();
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

    /// @dev Helper function to generate commitment hashes
    function hashCommitment(CallLib.Call[] memory _calls, bytes32 _salt) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_salt, abi.encode(_calls)));
    }

    function _addressToBytes32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(address(_address))));
    }

    function _overwriteMailbox(address mailboxAddress, address ismAddress, uint32 domain)
        private
        returns (MultichainMockMailbox)
    {
        vm.allowCheatcodes(mailboxAddress);
        deployCodeTo('MultichainMockMailbox.sol', abi.encode(domain), mailboxAddress);
        if (ismAddress != address(0)) deployCodeTo('TestIsm.sol', ismAddress);

        return MultichainMockMailbox(mailboxAddress);
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
