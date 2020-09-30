// contracts/Cramer.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract NormalModel is Ownable, ERC20 {
    uint16 public burnFee = 12; //burn fee
    uint16 public P3DGama = 20; // giant whale attenuation value
    uint16 public heightInitial = 10000; //fomo interval height
    uint16 public heightIncremental = 10; //fomo increasing height
    uint16 public P3DFee = 3; //P3D dividend fees 33%
    uint16 public devFee = 20; //community developer fees 5%
    uint16[] public FOMOFees = [50, 50, 50, 50, 50, 50, 50, 50, 50, 10]; // fomo dividend fee array 2% 2% 2% 2% 2% 2% 2% 2% 2% 10%
    uint256 public fomoDividendPool = 0; //dividends that have been distributed but not yet withdrawn
    uint256 public FOMOMinReq = (2000 * 1e18); //fomo minimum requirement
    uint256 public FOMOMinInitial = (2000 * 1e18);
    uint256 public FOMOMinIncremental = (20 * 1e18);
    uint256 public P3DMinReq = (2000 * 1e18); //p3d minimum requirement
    uint256 public targetHeight; //fomo target height
    uint256 public lastTargetHeight; // last fomo height
    uint256 public luckyCount = 0;
    uint256 public lastLuckyAmount = 0;
    uint256 public p3dDividendPool = 0;
    bool public gameStart = true;
    address private devAddress; //community developer address
    address[][] public awardArray;
    address[] public fomoAddress; //fomo participant address
    address[] public weightAddress; //Weighted address
    mapping(address => uint256) private _weights; //list of weights for dividend distribution
    mapping(address => uint256) private _fomoDividends; //Balance sheet after dividends
    mapping(address => uint256) private _p3dReceived;

    //Fomo Game The more people who play, the faster the pace, and the fewer people who play, the slower the pace.
    constructor(
        string memory name,
        string memory symbol,
        uint256 cap
    ) public ERC20(name, symbol) {
        devAddress = msg.sender;
        uint256 max = cap * 1e18;
        _mint(msg.sender, max);
        _refreshTargetHeight();
        _resetFomoAddress();
        lastTargetHeight = block.number;
    }

    function _resetFomoAddress() private {
        fomoAddress = [devAddress];
        FOMOMinReq = FOMOMinInitial;
    }

    function _refreshTargetHeight() private {
        targetHeight = SafeMath.add(block.number, heightInitial);
    }

    function _rewardFomo(uint256 _dividendSupply) private {
        uint256 _feeLen = FOMOFees.length;
        uint256 _addressLen = fomoAddress.length;
        uint256 _startIndex = _addressLen - _feeLen;
        uint256 _add = 0;
        address[] memory _awardArray = new address[](_feeLen);
        for (uint256 i = 0; i < _feeLen; i++) {
            address _recipient = fomoAddress[_startIndex + i];
            uint256 _amount = SafeMath.div(_dividendSupply, FOMOFees[i]);
            _add = _add.add(_amount);
            _fomoDividends[_recipient] = _fomoDividends[_recipient].add(
                _amount
            );
            _awardArray[i] = _recipient;
        }
        awardArray.push(_awardArray);
        _resetFomoAddress();
        lastLuckyAmount = _add;
        fomoDividendPool = fomoDividendPool.add(_add);
    }

    function _rewardP3D(uint256 _dividendSupply) private {
        uint256 _totalR = SafeMath.div(_dividendSupply, P3DFee);
        p3dDividendPool = p3dDividendPool.add(_totalR);
    }

    function _reward() private {
        uint256 _dividendSupply = dividendSupply();
        if (block.number >= targetHeight && _dividendSupply > 0) {
            if (fomoAddress.length < FOMOFees.length) {
                _refreshTargetHeight();
            } else {
                _rewardFomo(_dividendSupply);
                _rewardP3D(_dividendSupply);
                _refreshTargetHeight();
                luckyCount = luckyCount.add(1);
                lastTargetHeight = block.number;
            }
        }
    }

    function _updateFomo(address account, uint256 amount) private {
        if (amount >= FOMOMinReq) {
            targetHeight = SafeMath.add(targetHeight, heightIncremental);
            fomoAddress.push(account);
            FOMOMinReq = FOMOMinReq.add(FOMOMinIncremental);
            _reward();
        }
    }

    function _updateWeight(address _account, uint256 _amount) private {
        if (!Address.isContract(_account)) {
            if (_weights[_account] == 0) {
                weightAddress.push(_account);
            }
            if (_amount >= P3DMinReq) {
                uint256 _weight = calculateWeight(_amount);
                if (_weight == 0) {
                    _weights[_account] = 1;
                } else {
                    _weights[_account] = _weight;
                }
            } else {
                _weights[_account] = 1;
            }
        }
    }

    // internal

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (gameStart) {
            if (Address.isContract(recipient)) {
                super._transfer(sender, recipient, amount);
                _updateWeight(sender, balanceOf(sender));
            } else {
                uint256 _amountFrom = amount;
                uint256 _dividends = SafeMath.div(_amountFrom, burnFee);
                uint256 _amount = SafeMath.sub(_amountFrom, _dividends.mul(2));
                super._transfer(sender, address(this), _dividends);
                super._transfer(sender, recipient, _amount);
                _burn(sender, _dividends);
                _updateWeight(sender, balanceOf(sender));
                _updateWeight(recipient, balanceOf(recipient));
                _updateFomo(recipient, amount);
            }
        } else {
            super._transfer(sender, recipient, amount);
        }
    }

    //  onlyOwner
    function setGameStart(bool start) public onlyOwner {
        gameStart = start;
    }

    function setDividendFee(uint16 fee) public onlyOwner {
        burnFee = fee;
    }

    function setFOMOMinReq(
        uint256 v1,
        uint256 v2,
        uint256 v3
    ) public onlyOwner {
        FOMOMinReq = v1;
        FOMOMinInitial = v2;
        FOMOMinIncremental = v3;
    }

    function setP3DMinReq(uint256 v) public onlyOwner {
        P3DMinReq = v;
        for (uint256 i = 0; i < weightAddress.length; i++) {
            address account = weightAddress[i];
            _updateWeight(account, balanceOf(account));
        }
    }

    function setGama(uint16 v) public onlyOwner {
        P3DGama = v;
        for (uint256 i = 0; i < weightAddress.length; i++) {
            address account = weightAddress[i];
            _updateWeight(account, balanceOf(account));
        }
    }

    function setHeightInitial(uint16 v) public onlyOwner {
        heightInitial = v;
        _refreshTargetHeight();
    }

    function setHeightIncremental(uint16 v) public onlyOwner {
        heightIncremental = v;
    }

    function setFOMOFees(
        uint16 v1,
        uint16 v2,
        uint16 v3,
        uint16 v4,
        uint16 v5,
        uint16 v6,
        uint16 v7,
        uint16 v8,
        uint16 v9,
        uint16 v10
    ) public onlyOwner {
        FOMOFees = [v1, v2, v3, v4, v5, v6, v7, v8, v9, v10];
    }

    function withdrawDividends() public virtual {
        require(gameStart, "The game is paused");
        require(!p3dReceived(), "is Received");
        address _sender = msg.sender;
        uint256 _p3dAmount = p3dDividendsOf(_sender);
        uint256 _fomoAmount = fomoDividendsOf(_sender);
        uint256 _amount = _fomoAmount.add(_p3dAmount);
        delete _fomoDividends[_sender];
        fomoDividendPool = fomoDividendPool.sub(_fomoAmount);
        p3dDividendPool = p3dDividendPool.sub(_p3dAmount);
        _p3dReceived[_sender] = luckyCount;
        super._transfer(address(this), _sender, _amount);
        if (_amount > devFee) {
            _mint(devAddress, _amount.div(devFee));
        }
    }

    //  view
    function p3dReceived() public view returns (bool) {
        return _p3dReceived[msg.sender] >= luckyCount;
    }

    function weightAddressSize() public view returns (uint256) {
        return weightAddress.length;
    }

    function fomoAddressSize() public view returns (uint256) {
        return fomoAddress.length;
    }

    function weightOf(address _account) public view returns (uint256) {
        if (balanceOf(_account) > P3DMinReq) {
            return _weights[_account];
        } else {
            return 0;
        }
    }

    function weightSupply() public view returns (uint256) {
        uint256 _supply = 0;
        for (uint256 i = 0; i < weightAddress.length; i++) {
            address account = weightAddress[i];
            _supply = _supply.add(weightOf(account));
        }
        return _supply;
    }

    function dividendSupply() public view returns (uint256) {
        return
            balanceOf(address(this)).sub(fomoDividendPool).sub(p3dDividendPool);
    }

    function fomoDividendsOf(address account) public view returns (uint256) {
        uint256 _amount = _fomoDividends[account];
        return _amount;
    }

    function p3dDividendsOf(address _account) public view returns (uint256) {
        uint256 _weight = weightOf(_account);
        uint256 _amount = 0;
        if (_weight > 0) {
            _amount = SafeMath.div(
                SafeMath.mul(p3dDividendPool, _weight),
                weightSupply()
            );
        }
        return _amount;
    }

    function dividendsOf(address _account) public view returns (uint256) {
        uint256 _amount = fomoDividendsOf(_account).add(
            p3dDividendsOf(_account)
        );
        return _amount;
    }

    function calculateWeight(uint256 amount) public view returns (uint256) {
        uint256 _div = SafeMath.div(amount, P3DMinReq);
        uint256 _gama = SafeMath.div(_div, P3DGama);
        uint256 _b = SafeMath.mul(_gama, _gama);
        if (_div >= _b) {
            uint256 _weight = SafeMath.sub(_div, _b);
            return _weight;
        }
        return 0;
    }
}
