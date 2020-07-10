pragma solidity ^0.6.0;

import "./ERC20Minimal.sol";
import "../@openzeppelin/contracts/cryptography/ECDSA.sol";

contract ERC20Snapshot is ERC20Minimal {
	address public signerAddress;
	constructor (address _signerAddress) 
	public
	ERC20Minimal('HEX Snapshot', 'HEX-SNP')
	{
		signerAddress = _signerAddress;
	}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

	function addToSnapshot(address account, uint256 amount, bytes32) public {
		require(msg.sender == signerAddress, "only for signer address");
		_mint(account, amount);
	}

	function addToSnapshotMultiple(address[] memory accounts, uint256[] memory amounts) public returns (bool) {
		require(msg.sender == signerAddress, "only for signer address");
        require(accounts.length == amounts.length);

        for (uint i = 0; i < accounts.length; i ++) {
            _mint(accounts[i], amounts[i]);
        }

        return true;
    }


	function getMessageHash(uint256 amount, address account) public pure returns (bytes32) {
        return keccak256(abi.encode(amount, account));
    }

    function check(uint256 amount, bytes memory signature) public view returns (bool) {
        bytes32 messageHash =  getMessageHash(amount, address(msg.sender));
        return ECDSA.recover(messageHash, signature) == signerAddress;
    }


}