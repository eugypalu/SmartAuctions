pragma solidity 0.5.6;

import "./nf-token-metadata.sol";
import "./ownable.sol";

/**
 * @dev This is an example contract implementation of NFToken with metadata extension.
 */
contract P2pToken is
  NFTokenMetadata,
  Ownable
{

  /**
   * @dev Contract constructor. Sets metadata extension `name` and `symbol`.
   */
  constructor()
    public
  {
    nftName = "EugP2PToken";
    nftSymbol = "Eug";
  }

  /**
   * @dev Mints a new NFT.
   * @param _to The address that will own the minted NFT.
   * @param _tokenId of the NFT to be minted by the msg.sender.
   * @param _uri String representing RFC 3986 URI.
   */
  function mint(
    address _to,
    uint256 _tokenId,
    string calldata _uri,
    string calldata _descr
  )
    external
    onlyOwner
  {
    super._mint(_to, _tokenId);
    super._setTokenUri(_tokenId, _uri);
    super._setTokenDescription(_tokenId, _descr);
  }

}