// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import {Permit2} from 'permit2/src/Permit2.sol';
import {RouterDeployParameters} from 'contracts/types/RouterDeployParameters.sol';
import {UnsupportedProtocol} from 'contracts/deploy/UnsupportedProtocol.sol';
import {UniversalRouter} from 'contracts/UniversalRouter.sol';
import {ICreateX} from 'contracts/interfaces/external/ICreateX.sol';
import {CreateXLibrary} from 'contracts/libraries/CreateXLibrary.sol';
import {Constants} from 'script/Constants.sol';

abstract contract DeployUniversalRouter is Script, Constants {
    using CreateXLibrary for bytes11;

    error InvalidAddress(address expected, address output);
    error InvalidOutputFilename();

    struct DeploymentParameters {
        address weth9;
        address v2Factory;
        address v3Factory;
        bytes32 pairInitCodeHash;
        bytes32 poolInitCodeHash;
        address v4PoolManager;
        address veloV2Factory;
        address veloCLFactory;
        bytes32 veloV2InitCodeHash;
        bytes32 veloCLInitCodeHash;
    }

    DeploymentParameters internal params;
    RouterDeployParameters internal routerParams;
    UniversalRouter public router;

    address public permit2 = 0x494bbD8A3302AcA833D307D11838f18DbAdA9C25;
    address public unsupported = 0x61fF070AD105D5aa6d8F9eA21212CB574EeFCAd5;

    address public deployer = 0x4994DacdB9C57A811aFfbF878D92E00EF2E5C4C2;

    address constant UNSUPPORTED_PROTOCOL = address(0);
    bytes32 constant BYTES32_ZERO = bytes32(0);

    ICreateX public cx = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    bool public isTest = false;
    string public outputFilename = '';

    // set values for params and unsupported
    function setUp() public virtual;

    function run() external {
        vm.startBroadcast(deployer);

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
            veloCLInitCodeHash: params.veloCLInitCodeHash
        });

        deploy();

        logParams();
        logOutput();

        console.log('Universal Router Deployed:', address(router));
        vm.stopBroadcast();
    }

    function deploy() internal virtual {
        router = UniversalRouter(
            payable(
                cx.deployCreate3({
                    salt: UNIVERSAL_ROUTER_ENTROPY_V3.calculateSalt({_deployer: deployer}),
                    initCode: abi.encodePacked(type(UniversalRouter).creationCode, abi.encode(routerParams))
                })
            )
        );

        checkAddress({_entropy: UNIVERSAL_ROUTER_ENTROPY_V3, _output: address(router)});
    }

    function logParams() internal view {
        if (isTest) return;
        console.log('permit2:', permit2);
        console.log('weth9:', params.weth9);
        console.log('v2Factory:', params.v2Factory);
        console.log('v3Factory:', params.v3Factory);
        console.log('v4PoolManager:', params.v4PoolManager);
        console.log('veloV2Factory:', params.veloV2Factory);
    }

    function mapUnsupported(address protocol) internal view returns (address) {
        return protocol == address(0) ? unsupported : protocol;
    }

    /// @dev Check if the computed address matches the address produced by the deployment
    function checkAddress(bytes11 _entropy, address _output) internal view {
        address computedAddress = _entropy.computeCreate3Address({_deployer: deployer});
        if (computedAddress != _output) {
            revert InvalidAddress(computedAddress, _output);
        }
    }

    function verifyCreate3() internal view {
        /// if not run locally
        if (block.chainid != 31337) {
            uint256 size;
            address contractAddress = address(cx);
            assembly {
                size := extcodesize(contractAddress)
            }

            bytes memory bytecode = new bytes(size);
            assembly {
                extcodecopy(contractAddress, add(bytecode, 32), 0, size)
            }

            assert(keccak256(bytecode) == bytes32(0xbd8a7ea8cfca7b4e5f5041d7d4b17bc317c5ce42cfbc42066a00cf26b43eb53f));
        }
    }

    function logOutput() internal {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, '/deployment-addresses/', outputFilename));
        if (keccak256(bytes(outputFilename)) == keccak256(bytes(''))) revert InvalidOutputFilename();
        /// @dev This might overwrite an existing output file
        vm.writeJson(vm.serializeAddress('', 'Permit2', permit2), path);
        vm.writeJson(vm.serializeAddress('', 'UniversalRouter', address(router)), path);
        vm.writeJson(vm.serializeAddress('', 'UnsupportedProtocol', unsupported), path);
    }
}
