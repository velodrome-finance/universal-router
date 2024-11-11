// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/console2.sol';
import 'forge-std/Script.sol';
import {RouterParameters} from 'contracts/base/RouterImmutables.sol';
import {UnsupportedProtocol} from 'contracts/deploy/UnsupportedProtocol.sol';
import {UniversalRouter} from 'contracts/UniversalRouter.sol';
import {Permit2} from 'permit2/src/Permit2.sol';
import {ICreateX} from 'contracts/interfaces/external/ICreateX.sol';
import {CreateXLibrary} from 'contracts/libraries/CreateXLibrary.sol';

bytes32 constant SALT = bytes32(uint256(0x00000000000000000000000000000000000000005eb67581652632000a6cbedf));

bytes11 constant UNIVERSAL_ROUTER_ENTROPY = 0x0000000000000000000060;

abstract contract DeployUniversalRouter is Script {
    using CreateXLibrary for bytes11;

    error InvalidAddress(address expected, address output);
    error InvalidOutputFilename();

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
        if (params.permit2 == address(0)) {
            address permit2 = address(new Permit2{salt: SALT}());
            params.permit2 = permit2;
            console2.log('Permit2 Deployed:', address(permit2));
        }

        // only deploy unsupported if this chain doesn't already have one
        if (unsupported == address(0)) {
            unsupported = address(new UnsupportedProtocol());
            console2.log('UnsupportedProtocol deployed:', unsupported);
        }

        params = RouterParameters({
            permit2: mapUnsupported(params.permit2),
            weth9: mapUnsupported(params.weth9),
            seaportV1_5: mapUnsupported(params.seaportV1_5),
            seaportV1_4: mapUnsupported(params.seaportV1_4),
            openseaConduit: mapUnsupported(params.openseaConduit),
            nftxZap: mapUnsupported(params.nftxZap),
            x2y2: mapUnsupported(params.x2y2),
            foundation: mapUnsupported(params.foundation),
            sudoswap: mapUnsupported(params.sudoswap),
            elementMarket: mapUnsupported(params.elementMarket),
            nft20Zap: mapUnsupported(params.nft20Zap),
            cryptopunks: mapUnsupported(params.cryptopunks),
            looksRareV2: mapUnsupported(params.looksRareV2),
            routerRewardsDistributor: mapUnsupported(params.routerRewardsDistributor),
            looksRareRewardsDistributor: mapUnsupported(params.looksRareRewardsDistributor),
            looksRareToken: mapUnsupported(params.looksRareToken),
            v2Factory: mapUnsupported(params.v2Factory),
            v3Factory: mapUnsupported(params.v3Factory),
            v2Implementation: params.v2Implementation,
            clImplementation: params.clImplementation
        });

        deploy();

        logParams();

        console2.log('Universal Router Deployed:', address(router));
        vm.stopBroadcast();
    }

    function deploy() internal virtual {
        router = UniversalRouter(
            payable(
                cx.deployCreate3({
                    salt: UNIVERSAL_ROUTER_ENTROPY.calculateSalt({_deployer: deployer}),
                    initCode: abi.encodePacked(type(UniversalRouter).creationCode, abi.encode(params))
                })
            )
        );

        checkAddress({_entropy: UNIVERSAL_ROUTER_ENTROPY, _output: address(router)});
    }

    function logParams() internal view {
        if (isTest) return;
        console2.log('permit2:', params.permit2);
        console2.log('weth9:', params.weth9);
        console2.log('seaportV1_5:', params.seaportV1_5);
        console2.log('seaportV1_4:', params.seaportV1_4);
        console2.log('openseaConduit:', params.openseaConduit);
        console2.log('nftxZap:', params.nftxZap);
        console2.log('x2y2:', params.x2y2);
        console2.log('foundation:', params.foundation);
        console2.log('sudoswap:', params.sudoswap);
        console2.log('elementMarket:', params.elementMarket);
        console2.log('nft20Zap:', params.nft20Zap);
        console2.log('cryptopunks:', params.cryptopunks);
        console2.log('looksRareV2:', params.looksRareV2);
        console2.log('routerRewardsDistributor:', params.routerRewardsDistributor);
        console2.log('looksRareRewardsDistributor:', params.looksRareRewardsDistributor);
        console2.log('looksRareToken:', params.looksRareToken);
        console2.log('v2Factory:', params.v2Factory);
        console2.log('v3Factory:', params.v3Factory);
        console2.log('UniversalRouter:', address(router));
        console2.log('UnsupportedProtocol:', unsupported);
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
        if (bytes(outputFilename).length == 0) revert InvalidOutputFilename();
        /// @dev This might overwrite an existing output file
        vm.writeJson(vm.serializeAddress('', 'Permit2', params.permit2), path);
        vm.writeJson(vm.serializeAddress('', 'UniversalRouter', address(router)), path);
        vm.writeJson(vm.serializeAddress('', 'UnsupportedProtocol', unsupported), path);
    }
}
