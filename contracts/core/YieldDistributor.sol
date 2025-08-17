// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

/// @title YieldDistributor
/// @author NORA AI
/// @notice Manages yield calculation, fee distribution, and performance tracking for the autoUSD protocol.
/// This contract works in conjunction with the MotherVault. It does not hold funds but acts as a calculator
/// and record-keeper. The MotherVault queries this contract to determine fee amounts, transfers the fees,
/// and then instructs this contract to record the harvest details.
contract YieldDistributor is ReentrancyGuard, AccessControl {
    bytes32 public constant MOTHER_VAULT_ROLE = keccak256("MOTHER_VAULT_ROLE");

    /// @notice The USDC token contract instance.
    IERC20 public immutable USDC;
    /// @notice The address of the MotherVault contract, which is the sole controller of harvests.
    address public immutable motherVault;
    /// @notice The address of the protocol treasury where management fees are sent.
    address public treasury;

    /// @notice The management fee charged on yield, in basis points (1 bps = 0.01%).
    uint256 public managementFeeBps;

    /// @notice A snapshot of performance metrics for a single harvest cycle.
    struct PerformanceSnapshot {
        uint256 timestamp;
        uint256 grossYield;
        uint256 managementFees;
        uint256 netYield;
        uint256 totalNav; // NAV after harvest and fee distribution
    }

    /// @notice An array storing the history of all performance snapshots.
    PerformanceSnapshot[] public performanceHistory;
    /// @notice The last recorded Net Asset Value of the MotherVault after a harvest.
    uint256 public lastTotalNav;
    /// @notice The timestamp of the last recorded harvest.
    uint256 public lastHarvestTime;

    // --- Events ---

    /// @notice Emitted when a harvest has been processed and recorded.
    event HarvestRecorded(
        uint256 indexed timestamp, uint256 grossYield, uint256 managementFees, uint256 netYield, uint256 newTotalNav
    );

    /// @notice Emitted when the treasury address is updated.
    event TreasuryUpdated(address indexed newTreasury);
    /// @notice Emitted when the management fee is updated.
    event ManagementFeeUpdated(uint256 indexed newFeeBps);

    // --- Errors ---

    /// @notice Thrown for invalid fee configurations.
    error InvalidFee(string message);
    /// @notice Thrown for invalid address arguments.
    error InvalidAddress(string message);

    // --- Constructor ---

    /// @param _usdc The address of the USDC token contract.
    /// @param _motherVault The address of the MotherVault contract.
    /// @param _treasury The address of the protocol treasury.
    /// @param _managementFeeBps The initial management fee in basis points.
    constructor(address _usdc, address _motherVault, address _treasury, uint256 _managementFeeBps) {
        if (_usdc == address(0) || _motherVault == address(0) || _treasury == address(0)) {
            revert InvalidAddress("Zero address provided");
        }
        if (_managementFeeBps > 10_000) {
            // 100%
            revert InvalidFee("Fee cannot exceed 100%");
        }

        USDC = IERC20(_usdc);
        motherVault = _motherVault;
        treasury = _treasury;
        managementFeeBps = _managementFeeBps;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MOTHER_VAULT_ROLE, _motherVault);
    }

    // --- Admin Functions ---

    /// @notice Updates the treasury address.
    /// @param _newTreasury The new address for the treasury.
    function setTreasury(address _newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newTreasury == address(0)) {
            revert InvalidAddress("Cannot set treasury to zero address");
        }
        treasury = _newTreasury;
        emit TreasuryUpdated(_newTreasury);
    }

    /// @notice Updates the management fee.
    /// @param _newFeeBps The new fee in basis points.
    function setManagementFee(uint256 _newFeeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newFeeBps > 10_000) {
            // Max 100%
            revert InvalidFee("Fee cannot exceed 100%");
        }
        managementFeeBps = _newFeeBps;
        emit ManagementFeeUpdated(_newFeeBps);
    }

    /// @notice Sets the initial NAV. Can only be called once by the admin.
    /// @param _initialNav The initial NAV of the MotherVault.
    function setInitialNav(uint256 _initialNav) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (lastTotalNav != 0) revert("Initial NAV already set");
        lastTotalNav = _initialNav;
    }

    // --- Core Logic ---

    /// @notice Calculates the management fee and net yield from a given gross yield.
    /// @param _grossYield The total yield generated before any fees.
    /// @return managementFee The portion of the yield allocated as management fees.
    /// @return netYield The portion of the yield remaining after fees.
    function calculateFees(uint256 _grossYield) public view returns (uint256 managementFee, uint256 netYield) {
        managementFee = (_grossYield * managementFeeBps) / 10_000;
        netYield = _grossYield - managementFee;
        return (managementFee, netYield);
    }

    /// @notice Records the details of a harvest cycle.
    /// @dev This function must only be called by the MotherVault after it has processed a harvest and
    /// distributed the fees. It updates the performance history and state variables.
    /// @param _grossYield The gross yield generated during the cycle.
    /// @param _newTotalNav The new total NAV of the MotherVault after the harvest and fee distribution.
    function recordHarvest(
        uint256 _grossYield,
        uint256 _newTotalNav
    )
        external
        nonReentrant
        onlyRole(MOTHER_VAULT_ROLE)
    {
        (uint256 managementFee, uint256 netYield) = calculateFees(_grossYield);

        lastTotalNav = _newTotalNav;
        lastHarvestTime = block.timestamp;

        performanceHistory.push(
            PerformanceSnapshot({
                timestamp: block.timestamp,
                grossYield: _grossYield,
                managementFees: managementFee,
                netYield: netYield,
                totalNav: _newTotalNav
            })
        );

        emit HarvestRecorded(block.timestamp, _grossYield, managementFee, netYield, _newTotalNav);
    }

    // --- View Functions ---

    /// @notice Returns a performance snapshot by its index.
    /// @param _index The index of the snapshot in the performanceHistory array.
    /// @return The PerformanceSnapshot struct.
    function getPerformanceSnapshot(uint256 _index) external view returns (PerformanceSnapshot memory) {
        return performanceHistory[_index];
    }

    /// @notice Returns the number of performance snapshots recorded.
    /// @return The length of the performanceHistory array.
    function getPerformanceHistoryLength() external view returns (uint256) {
        return performanceHistory.length;
    }
}
