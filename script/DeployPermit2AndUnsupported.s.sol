// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import 'forge-std/console2.sol';
import 'forge-std/Script.sol';
import {Permit2} from 'permit2/src/Permit2.sol';
import {UnsupportedProtocol} from 'contracts/deploy/UnsupportedProtocol.sol';
import {ICreateX} from 'contracts/interfaces/external/ICreateX.sol';
import {CreateXLibrary} from 'contracts/libraries/CreateXLibrary.sol';
import {Constants} from 'script/Constants.sol';

contract DeployPermit2AndUnsupported is Script, Constants {
    using CreateXLibrary for bytes11;

    error InvalidAddress(address expected, address output);
    error InvalidOutputFilename();

    address public unsupported;
    address public permit2;

    address public deployer = 0x4994DacdB9C57A811aFfbF878D92E00EF2E5C4C2;

    ICreateX public cx = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    bool public isTest = false;
    string public outputFilename = '';

    function run() external {
        vm.startBroadcast(deployer);

        deployPermit2();
        deployUnsupported();

        logOutput();

        vm.stopBroadcast();
    }

    function deployPermit2() internal virtual {
        permit2 = cx.deployCreate3({
            salt: PERMIT2_ENTROPY.calculateSalt({_deployer: deployer}),
            initCode: abi.encodePacked(type(Permit2).creationCode)
        });

        checkAddress({_entropy: PERMIT2_ENTROPY, _output: permit2});
    }

    function deployUnsupported() internal virtual {
        unsupported = cx.deployCreate3({
            salt: UNSUPPORTED_PROTOCOL_ENTROPY.calculateSalt({_deployer: deployer}),
            initCode: abi.encodePacked(type(UnsupportedProtocol).creationCode)
        });

        checkAddress({_entropy: UNSUPPORTED_PROTOCOL_ENTROPY, _output: unsupported});
    }

    /// @dev Check if the computed address matches the address produced by the deployment
    function checkAddress(bytes11 _entropy, address _output) internal view {
        address computedAddress = _entropy.computeCreate3Address({_deployer: deployer});
        if (computedAddress != _output) {
            revert InvalidAddress(computedAddress, _output);
        }
    }

    function logOutput() internal {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, '/deployment-addresses/', outputFilename));
        if (keccak256(bytes(outputFilename)) == keccak256(bytes(''))) revert InvalidOutputFilename();
        /// @dev This might overwrite an existing output file
        vm.writeJson(vm.serializeAddress('', 'Permit2', permit2), path);
        vm.writeJson(vm.serializeAddress('', 'UnsupportedProtocol', unsupported), path);
    }
}
