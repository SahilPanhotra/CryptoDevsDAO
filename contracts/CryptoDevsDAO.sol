//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Interface for the FakeNFTMarketplace
 */
interface IFakeNFTMarketplace {
    /// @dev getPrice() returns the price of an NFT from the FakeNFTMarketplace
    /// @return Returns the price in Wei for an NFT
    function getPrice() external view returns (uint256);

    /// @dev available() returns whether or not the given _tokenId has already been purchased
    /// @return Returns a boolean value - true if available, false if not
    function available(uint256 _tokenId) external view returns (bool);

    /// @dev purchase() purchases an NFT from the FakeNFTMarketplace
    /// @param _tokenId - the fake NFT tokenID to purchase
    function purchase(uint256 _tokenId) external payable;
}

/**
 * Minimal interface for CryptoDevsNFT containing only two functions
 * that we are interested in
 */
interface ICryptoDevsNFT {
    /// @dev balanceOf returns the number of NFTs owned by the given address
    /// @param owner - address to fetch number of NFTs for
    /// @return Returns the number of NFTs owned
    function balanceOf(address owner) external view returns (uint256);

    /// @dev tokenOfOwnerByIndex returns a tokenID at given index for owner
    /// @param owner - address to fetch the NFT TokenID for
    /// @param index - index of NFT in owned tokens array to fetch
    /// @return Returns the TokenID of the NFT
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);
}

contract CryptoDevsDAO is Ownable {
 struct Proposal {
     uint256 nftTokenId;
     uint256 deadline;
     uint256 yayVotes;
     uint256 nayVotes;
     bool executed;
     mapping(uint256 => bool) voters;
 }
 mapping(uint => Proposal) public proposals;
 uint256 public numProposals;

 IFakeNFTMarketplace nftMarketplace;
 ICryptoDevsNFT cryptoDevsNFT;

 constructor(address _nftMarketplace,address _cryptoDevsNFT) payable{
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
 }

 modifier nftHolderOnly {
     require(cryptoDevsNFT.balanceOf(msg.sender)>0 ,"NOT_A_DAO_MEMBER");
     _;
 }

 function createProposal(uint256 _nftTokenId) external nftHolderOnly returns (uint256) {
        require(nftMarketplace.available(_nftTokenId),"Nft not available for purchase");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId=_nftTokenId;
        proposal.deadline = block.timestamp + 5 minutes;
        numProposals++;
        return numProposals-1;
 }

 modifier activeProposalOnly(uint proposalIndex) {
     require(proposals[proposalIndex].deadline > block.timestamp,"DEADLINE_EXCEEDED");
     _;
 }
 enum Vote {
    YAY, 
    NAY
}
 function voteOnProposal(uint proposalIndex,Vote vote) external nftHolderOnly activeProposalOnly(proposalIndex) {
     Proposal storage proposal = proposals[proposalIndex];
      uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
      uint256 numVotes = 0;
      for(uint i=0;i<voterNFTBalance;i++){
          uint256 tokenId=cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
          if(proposal.voters[tokenId]==false){
              numVotes++;
            proposal.voters[tokenId] = true;
          }
      }
      require(numVotes>0,"No Votes or Already votes");
      if(vote== Vote.YAY){
          proposal.yayVotes+=numVotes;
      }
      else {
        proposal.nayVotes += numVotes;
    }
     
 }
 modifier inactiveProposalOnly (uint proposalIndex){
     require(proposals[proposalIndex].deadline <= block.timestamp,"DEADLINE_NOT_EXCEEDED");
     require(proposals[proposalIndex].executed==false,"PROPOSAL ALREADY EXECUTED");
     _;
 }
 function executeProposal(uint256 proposalIndex) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
     Proposal storage proposal = proposals[proposalIndex];
     if (proposal.yayVotes > proposal.nayVotes){
         uint256 nftPrice = nftMarketplace.getPrice();
         require(address(this).balance >= nftPrice,"Not enough funds");
         nftMarketplace.purchase{value:nftPrice}(proposal.nftTokenId);
     }
     proposal.executed=true;
     
 }
 
function withdrawEther() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
}
receive() external payable {}

fallback() external payable {}


}
