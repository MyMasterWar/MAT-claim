// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "./ReentrancyGuard.sol";
import "./Ownable.sol";
import "./IBEP20.sol";
import "./SafeMath.sol";

contract MATTreasuryClaim is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    IBEP20 public MAT;

    uint256 public VESTING_DURATION = 86400 * 30 * 60; //60 months

    uint256 public startTime;
    uint256 public endTime;

    uint8 public stage;

    address public constant TREASURY_ADDRESS =
        0xF3a3F29C1F846CbDe9A17A161DF4c68243e3003f;
    uint256 lock;
    uint256 released;

    event Claim(address indexed account, uint256 amount, uint256 time);

    constructor(IBEP20 _mat) {
        MAT = IBEP20(_mat);
        stage = 0;
        lock = 15000000000000000000000000; //15,000,000 MAT
    }

    function setTgeTime(uint256 _tge) external onlyOwner {
        require(stage == 0, "Can not setup tge");
        startTime = _tge;
        endTime = startTime + VESTING_DURATION;

        stage = 1;
    }

    function claim() external nonReentrant {
        require(stage == 1, "Can not claim now");
        require(block.timestamp > startTime, "still locked");
        require(_msgSender() == TREASURY_ADDRESS, "Address invalid");
        require(lock > released, "no locked");

        uint256 amount = canUnlockAmount();
        require(amount > 0, "Nothing to claim");

        released += amount;

        MAT.transfer(_msgSender(), amount);

        emit Claim(_msgSender(), amount, block.timestamp);
    }

    function canUnlockAmount() public view returns (uint256) {
        if (block.timestamp < startTime) {
            return 0;
        } else if (block.timestamp >= endTime) {
            return lock - released;
        } else {
            uint256 releasedTime = releasedTimes();
            uint256 totalVestingTime = endTime - startTime;
            return ((lock * releasedTime) / totalVestingTime) - released;
        }
    }

    function releasedTimes() public view returns (uint256) {
        uint256 targetNow = (block.timestamp >= endTime)
            ? endTime
            : block.timestamp;
        uint256 releasedTime = targetNow - startTime;
        return releasedTime;
    }

    function info()
        external
        view
        returns (
            uint8,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        if (stage == 0) return (stage, startTime, endTime, lock, released, 0);
        return (stage, startTime, endTime, lock, released, canUnlockAmount());
    }

    /* ========== EMERGENCY ========== */
    function governanceRecoverUnsupported(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        require(
            _token != address(MAT) ||
                MAT.balanceOf(address(this)) - _amount >= lock - released,
            "Not enough locked amount left"
        );
        IBEP20(_token).transfer(_to, _amount);
    }
}
