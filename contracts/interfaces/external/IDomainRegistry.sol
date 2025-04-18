// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDomainRegistry {
    error AlreadyRegistered();
    error NotRegistered();
    error InvalidDomain();

    event DomainRegistered(uint32 indexed _domain);
    event DomainDeregistered(uint32 indexed _domain);

    /// @notice Returns set of all registered domains
    /// @return An array of all registered domains
    function domains() external view returns (uint256[] memory);

    /// @notice Checks if a domain is registered
    /// @param _domain The domain to check
    /// @return True if the domain is registered, false otherwise
    function contains(uint32 _domain) external view returns (bool);

    /// @notice Registers a new domain
    /// @dev Only callable by the owner, allows messages to the registered domain
    /// @param _domain The domain to register
    function registerDomain(uint32 _domain) external;

    /// @notice Deregisters a domain
    /// @dev Only callable by the owner, disallows messages to the deregistered domain
    /// @param _domain The domain to deregister
    function deregisterDomain(uint32 _domain) external;
}
