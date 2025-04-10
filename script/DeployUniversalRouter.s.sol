// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import 'forge-std/console2.sol';
import 'forge-std/Script.sol';
import {RouterParameters} from 'contracts/types/RouterParameters.sol';
import {UnsupportedProtocol} from 'contracts/deploy/UnsupportedProtocol.sol';
import {UniversalRouter} from 'contracts/UniversalRouter.sol';
import {ICreateX} from 'contracts/interfaces/external/ICreateX.sol';
import {CreateXLibrary} from 'contracts/libraries/CreateXLibrary.sol';

bytes32 constant SALT = bytes32(uint256(0x00000000000000000000000000000000000000005eb67581652632000a6cbedf));

bytes11 constant UNIVERSAL_ROUTER_ENTROPY = 0x0000000000000000000060; // used previously, no longer usable
bytes11 constant UNIVERSAL_ROUTER_ENTROPY_V2 = 0x0000000000000000000061;

abstract contract DeployUniversalRouter is Script {
    using CreateXLibrary for bytes11;

    error InvalidAddress(address expected, address output);
    error InvalidOutputFilename();
    error Permit2NotDeployed();

    RouterParameters internal params;
    UniversalRouter public router;

    address internal unsupported;

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

        // deploy permit2 if it isnt yet deployed
        if (params.permit2 == address(0)) revert Permit2NotDeployed();

        // only deploy unsupported if this chain doesn't already have one
        if (unsupported == address(0)) {
            unsupported = address(new UnsupportedProtocol());
            console2.log('UnsupportedProtocol deployed:', unsupported);
        }

        params = RouterParameters({
            permit2: mapUnsupported(params.permit2),
            weth9: mapUnsupported(params.weth9),
            v2Factory: mapUnsupported(params.v2Factory),
            v3Factory: mapUnsupported(params.v3Factory),
            pairInitCodeHash: params.pairInitCodeHash,
            poolInitCodeHash: params.poolInitCodeHash,
            v4PoolManager: mapUnsupported(params.v4PoolManager),
            v3NFTPositionManager: mapUnsupported(params.v3NFTPositionManager),
            v4PositionManager: mapUnsupported(params.v4PositionManager),
            veloV2Factory: mapUnsupported(params.veloV2Factory),
            veloCLFactory: mapUnsupported(params.veloCLFactory),
            veloV2InitCodeHash: params.veloV2InitCodeHash,
            veloCLInitCodeHash: params.veloCLInitCodeHash,
            rootHLMessageModule: params.rootHLMessageModule
        });

        deploy();

        logParams();
        logOutput();

        console2.log('Universal Router Deployed:', address(router));
        vm.stopBroadcast();
    }

    function deploy() internal virtual {
        router = UniversalRouter(
            payable(
                cx.deployCreate3({
                    salt: UNIVERSAL_ROUTER_ENTROPY_V2.calculateSalt({_deployer: deployer}),
                    initCode: abi.encodePacked(type(UniversalRouter).creationCode, abi.encode(params))
                })
            )
        );

        checkAddress({_entropy: UNIVERSAL_ROUTER_ENTROPY_V2, _output: address(router)});
    }

    function logParams() internal view {
        if (isTest) return;
        console2.log('permit2:', params.permit2);
        console2.log('weth9:', params.weth9);
        console2.log('v2Factory:', params.v2Factory);
        console2.log('v3Factory:', params.v3Factory);
        console2.log('v4PoolManager:', params.v4PoolManager);
        console2.log('v3NFTPositionManager:', params.v3NFTPositionManager);
        console2.log('v4PositionManager:', params.v4PositionManager);
        console2.log('veloV2Factory:', params.veloV2Factory);
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
        vm.writeJson(vm.serializeAddress('', 'Permit2', params.permit2), path);
        vm.writeJson(vm.serializeAddress('', 'UniversalRouter', address(router)), path);
        vm.writeJson(vm.serializeAddress('', 'UnsupportedProtocol', unsupported), path);
    }
}
