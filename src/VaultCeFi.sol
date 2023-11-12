// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@solmate/mixins/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// errors
error Vault_Not_Enough_Liquidity(uint256 maxBorrowCapatity);

contract VaultCeFi is ERC4626, Ownable {
    // events
    event Borrow(uint256 amount);
    event Refund(uint256 amount);

    using SafeTransferLib for ERC20;

    uint256 private borrowedFunds; // funds currently used
    uint256 private MAX_BORROW_RATIO = 8000; // 80%

    constructor(
        ERC20 _asset,
        address _admin
    )
        ERC4626(
            _asset,
            string.concat("Bank-", _asset.symbol()),
            string.concat("B", _asset.symbol())
        )
    {
        transferOwnership(_admin);
    }

    function borrow(uint256 _amountToBorrow) external onlyOwner {
        uint256 borrowCapacity = borrowCapacityLeft();
        if (_amountToBorrow > borrowCapacity) {
            revert Vault_Not_Enough_Liquidity(borrowCapacity);
        }
        borrowedFunds += _amountToBorrow;
        asset.safeTransfer(msg.sender, _amountToBorrow);

        emit Borrow(_amountToBorrow);
    }

    function refund(
        uint256 _amountBorrowed,
        uint256 _interests,
        uint256 _losses
    ) external onlyOwner {
        borrowedFunds = uint256(borrowedFunds - _amountBorrowed);
        uint256 sum_ = _amountBorrowed + _interests - _losses;
        asset.safeTransferFrom(msg.sender, address(this), sum_);
        emit Refund(sum_);
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this)) + borrowedFunds;
    }

    function rawTotalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function getBorrowedFund() external view returns (uint256) {
        return borrowedFunds;
    }

    function borrowCapacityLeft() public view returns (uint256) {
        return ((totalAssets() * MAX_BORROW_RATIO) / 10000) - borrowedFunds;
    }
}
