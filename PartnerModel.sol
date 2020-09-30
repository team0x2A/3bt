// contracts/Cramer.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.7.0;

import "./NormalModel.sol";

contract PartnerModel is NormalModel {
    uint256 public denominator = 5;
    uint256 public miniRequirements = (2000 * 1e18);
    uint256 public miniInvite = (100 * 1e18);
    mapping(address => uint256) private _partnerLevels;
    mapping(address => string) private _partnerPhrases;
    mapping(address => address) private _partnerships;
    mapping(string => address) private _phrasePartners;

    constructor(
        string memory name,
        string memory symbol,
        uint256 cap
    ) public NormalModel(name, symbol, cap) {}

    function setDenominator(uint256 _denominator) public onlyOwner {
        denominator = _denominator;
    }

    function setMiniRequirements(uint256 _miniRequirements) public onlyOwner {
        miniRequirements = _miniRequirements;
    }

    function _partnerRewards(
        address _to,
        address _partner,
        uint256 _amount
    ) private {
        uint256 _lv = _partnerLevels[_partner];
        uint256 _remainder = denominator - (_lv % denominator) + denominator; // 10 9 8 7 6
        uint256 _incentives = _amount.div(_remainder);
        uint256 _incentivesTo = _amount.div(denominator + denominator); // 1/10
        _mint(_to, _incentives);
        _mint(_partner, _incentivesTo);
    }

    function _updatePartnerShip(address from, address to) private {
        if (
            partnerShipOf(to) == address(0) &&
            !Address.isContract(from) &&
            !Address.isContract(to)
        ) {
            _partnerships[to] = from;
        }
    }

    function requestPartner(string memory _phrase) public {
        uint256 _balance = balanceOf(msg.sender);
        require(
            _balance > miniRequirements,
            "Does not meet the minimum partner requirements"
        );
        require(
            _phrasePartners[_phrase] == address(0),
            "Phrase already exists"
        );
        _phrasePartners[_phrase] = msg.sender;
        _partnerPhrases[msg.sender] = _phrase;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        super._transfer(sender, recipient, amount);
        if (amount >= miniInvite && sender != recipient) {
            _updatePartnerShip(sender, recipient);
        }
    }

    function partnerOf(string memory _phrase) public view returns (address) {
        return _phrasePartners[_phrase];
    }

    function phraseOf(address _account) public view returns (string memory) {
        return _partnerPhrases[_account];
    }

    function partnerShipOf(address _account) public view returns (address) {
        return _partnerships[_account];
    }

    function inviterOf(address _account) public view returns (string memory) {
        address _partner = partnerShipOf(_account);
        if (_partner != address(0)) {
            return phraseOf(_partner);
        } else {
            return "";
        }
    }

    function withdrawDividends() public override {
        address _sender = msg.sender;
        address _partner = partnerShipOf(_sender);
        if (_partner != address(0) && _partner != msg.sender) {
            uint256 _dividends = dividendsOf(_sender);
            _partnerRewards(_sender, _partner, _dividends);
        }
        super.withdrawDividends();
    }

    function withdrawDividendsWithPartner(string memory _phrase) public {
        address _partner = _phrasePartners[_phrase];
        require(_partner != address(0), "No Phrase");
        require(_partner != msg.sender, "Can not self");
        _updatePartnerShip(_partner, msg.sender);
        withdrawDividends();
    }
}
