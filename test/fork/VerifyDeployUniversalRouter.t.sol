// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import 'forge-std/Test.sol';
import 'forge-std/StdJson.sol';

import {DeployUniversalRouter} from 'script/DeployUniversalRouter.s.sol';
import {UniversalRouter} from 'contracts/UniversalRouter.sol';
import {RouterDeployParameters} from 'contracts/types/RouterDeployParameters.sol';

import {DeployBase} from 'script/deployParameters/DeployBase.s.sol';
import {DeployCelo} from 'script/deployParameters/DeployCelo.s.sol';
import {DeployFraxtal} from 'script/deployParameters/DeployFraxtal.s.sol';
import {DeployInk} from 'script/deployParameters/DeployInk.s.sol';
import {DeployLisk} from 'script/deployParameters/DeployLisk.s.sol';
import {DeployMetal} from 'script/deployParameters/DeployMetal.s.sol';
import {DeployMode} from 'script/deployParameters/DeployMode.s.sol';
import {DeployOptimism} from 'script/deployParameters/DeployOptimism.s.sol';
import {DeploySoneium} from 'script/deployParameters/DeploySoneium.s.sol';
import {DeploySuperseed} from 'script/deployParameters/DeploySuperseed.s.sol';
import {DeploySwell} from 'script/deployParameters/DeploySwell.s.sol';
import {DeployUnichain} from 'script/deployParameters/DeployUnichain.s.sol';

/// @notice Post-deploy verification test for already-deployed UniversalRouter.
///         Reads deployed addresses from the output JSON and verifies:
///         1. On-chain immutables match the deploy script parameters
///         2. Bytecode matches locally compiled artifacts (deploys fresh copy with same constructor args to compare)
///
///         Each chain has a concrete test contract that inherits from its deploy script,
///         reusing params and outputFilename directly.
abstract contract VerifyDeployUniversalRouterForkTest is DeployUniversalRouter, Test {
    using stdJson for string;

    function _loadOutput() internal {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, '/deployment-addresses/', outputFilename));
        string memory json = vm.readFile(path);

        router = UniversalRouter(payable(abi.decode(vm.parseJson(json, '.UniversalRouter'), (address))));
    }

    // =========================================================================
    // State verification
    // =========================================================================

    function test_verifyPaymentImmutables() public {
        assertEq(address(router.WETH9()), mapUnsupported(params.weth9), 'WETH9 mismatch');
        assertEq(address(router.PERMIT2()), permit2, 'PERMIT2 mismatch');
    }

    function test_verifyV4PoolManager() public {
        assertEq(address(router.poolManager()), mapUnsupported(params.v4PoolManager), 'V4 PoolManager mismatch');
    }

    // =========================================================================
    // Bytecode verification
    // =========================================================================

    // Deploys a fresh copy with the same constructor args and compares runtime
    // bytecode. This handles immutables correctly since same args = same values.

    function _getCode(address _addr) internal view returns (bytes memory code) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        code = new bytes(size);
        assembly {
            extcodecopy(_addr, add(code, 0x20), 0, size)
        }
    }

    /// @dev Strip the CBOR-encoded metadata appended by solc.
    ///      The last 2 bytes encode the metadata length; we remove that many bytes + 2.
    function _stripMetadata(bytes memory code) internal pure returns (bytes memory) {
        uint256 metaLen = uint256(uint8(code[code.length - 2])) << 8 | uint256(uint8(code[code.length - 1]));
        uint256 codeLen = code.length - metaLen - 2;
        bytes memory stripped = new bytes(codeLen);
        assembly {
            let src := add(code, 0x20)
            let dst := add(stripped, 0x20)
            for { let i := 0 } lt(i, codeLen) { i := add(i, 0x20) } { mstore(add(dst, i), mload(add(src, i))) }
        }
        return stripped;
    }

    function _assertBytecodeMatch(address _deployed, address _fresh, string memory _label) internal {
        bytes memory actual = _stripMetadata(_getCode(_deployed));
        bytes memory expected = _stripMetadata(_getCode(_fresh));
        assertEq(keccak256(actual), keccak256(expected), _label);
    }

    function test_verifyBytecode_UniversalRouter() public {
        routerParams = RouterDeployParameters({
            permit2: permit2,
            weth9: mapUnsupported(params.weth9),
            v2Factory: mapUnsupported(params.v2Factory),
            v3Factory: mapUnsupported(params.v3Factory),
            pairInitCodeHash: params.pairInitCodeHash,
            poolInitCodeHash: params.poolInitCodeHash,
            v4PoolManager: mapUnsupported(params.v4PoolManager),
            veloV2Factory: mapUnsupported(params.veloV2Factory),
            veloCLFactory: mapUnsupported(params.veloCLFactory),
            veloV2InitCodeHash: params.veloV2InitCodeHash,
            veloCLInitCodeHash: params.veloCLInitCodeHash,
            veloCLFactory2: mapUnsupported(params.veloCLFactory2),
            veloCLInitCodeHash2: params.veloCLInitCodeHash2,
            veloCLFactory3: mapUnsupported(params.veloCLFactory3),
            veloCLInitCodeHash3: params.veloCLInitCodeHash3
        });

        UniversalRouter fresh = new UniversalRouter(routerParams);
        _assertBytecodeMatch(address(router), address(fresh), 'UniversalRouter bytecode mismatch');
    }
}

// =========================================================================
// Chain-specific verification tests
// =========================================================================

contract VerifyDeployBase is VerifyDeployUniversalRouterForkTest, DeployBase {
    function setUp() public override(DeployBase, DeployUniversalRouter) {
        DeployBase.setUp();
        _loadOutput();
    }
}

contract VerifyDeployOptimism is VerifyDeployUniversalRouterForkTest, DeployOptimism {
    function setUp() public override(DeployOptimism, DeployUniversalRouter) {
        DeployOptimism.setUp();
        _loadOutput();
    }
}

contract VerifyDeployMode is VerifyDeployUniversalRouterForkTest, DeployMode {
    function setUp() public override(DeployMode, DeployUniversalRouter) {
        DeployMode.setUp();
        _loadOutput();
    }
}

contract VerifyDeployCelo is VerifyDeployUniversalRouterForkTest, DeployCelo {
    function setUp() public override(DeployCelo, DeployUniversalRouter) {
        DeployCelo.setUp();
        _loadOutput();
    }
}

contract VerifyDeployFraxtal is VerifyDeployUniversalRouterForkTest, DeployFraxtal {
    function setUp() public override(DeployFraxtal, DeployUniversalRouter) {
        DeployFraxtal.setUp();
        _loadOutput();
    }
}

contract VerifyDeployInk is VerifyDeployUniversalRouterForkTest, DeployInk {
    function setUp() public override(DeployInk, DeployUniversalRouter) {
        DeployInk.setUp();
        _loadOutput();
    }
}

contract VerifyDeployLisk is VerifyDeployUniversalRouterForkTest, DeployLisk {
    function setUp() public override(DeployLisk, DeployUniversalRouter) {
        DeployLisk.setUp();
        _loadOutput();
    }
}

contract VerifyDeployMetal is VerifyDeployUniversalRouterForkTest, DeployMetal {
    function setUp() public override(DeployMetal, DeployUniversalRouter) {
        DeployMetal.setUp();
        _loadOutput();
    }
}

contract VerifyDeploySoneium is VerifyDeployUniversalRouterForkTest, DeploySoneium {
    function setUp() public override(DeploySoneium, DeployUniversalRouter) {
        DeploySoneium.setUp();
        _loadOutput();
    }
}

contract VerifyDeploySuperseed is VerifyDeployUniversalRouterForkTest, DeploySuperseed {
    function setUp() public override(DeploySuperseed, DeployUniversalRouter) {
        DeploySuperseed.setUp();
        _loadOutput();
    }
}

contract VerifyDeploySwell is VerifyDeployUniversalRouterForkTest, DeploySwell {
    function setUp() public override(DeploySwell, DeployUniversalRouter) {
        DeploySwell.setUp();
        _loadOutput();
    }
}

contract VerifyDeployUnichain is VerifyDeployUniversalRouterForkTest, DeployUnichain {
    function setUp() public override(DeployUnichain, DeployUniversalRouter) {
        DeployUnichain.setUp();
        _loadOutput();
    }
}
