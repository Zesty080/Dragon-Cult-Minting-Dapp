// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import "./ScaleToken.sol";

interface Token {
    function mintToken(address _user, uint256 _mintAmount) external;

    function getBalance(address user) external;

    function scaleBurn(uint256 _value) external;
}

contract DragonCult is ERC721Enumerable, Ownable {
    using Strings for uint256;

    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    address public scaleToken;

    string public baseURI;
    string public baseExtension = "";
    uint256 public cost = 0.03 ether;
    uint256 public maxSupply = 1000;
    uint256 public maxMintAmount = 20;
    uint256 public mintCount;
    bool public paused = false;
    mapping(address => uint256) public deposited_tokens;
    mapping(address => bool) public has_deposited;
    mapping(address => uint256) public startTime;

    // wallet addresses for claims
    address private constant _dani = 0x31FbcD30AA07FBbeA5DB938cD534D1dA79E34985;
    address private constant _archie =
        0xd848353706E5a26BAa6DD20265EDDe1e7047d9ba;
    address private constant _nate = 0xC03e1522a67Ddd1c6767e2368B671bA92fea420F;
    address private constant _community =
        0x65dbAe8A5b650b526f424140645b80BC38d997e4;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        address scaletk
    ) payable ERC721(_name, _symbol) {
        setScaleAddr(scaletk);
        // mint 2 tokens for contract owner
        mint(msg.sender, 10, _initBaseURI);
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setScaleAddr(address _tokenadd) public payable {
        scaleToken = _tokenadd;
    }

    function mintScale(address _user, uint256 _mintAmount) public {
        Token(scaleToken).mintToken(_user, _mintAmount);
    }

    // get user scale balance
    function scaleBalance(address _user) public {
        Token(scaleToken).getBalance(_user);
    }

    // scale burn token function
    function scaleBurn(uint256 _amount) public {
        Token(scaleToken).scaleBurn(_amount);
    }

    function sendNft(
        address _reciever,
        address _sender,
        uint256 _tokenId
    ) public payable {
        safeTransferFrom(_sender, _reciever, _tokenId);
    }

    // nft deposit/stake function
    function deposit(uint256 _tokenId) public payable {
        require(!has_deposited[msg.sender], "Sender already staked token");

        _transfer(msg.sender, address(this), _tokenId);

        deposited_tokens[msg.sender] = _tokenId;
        has_deposited[msg.sender] = true;
        startTime[msg.sender] = block.timestamp;
    }

    // NFT minting function
    function mint(
        address _to,
        uint256 _mintAmount,
        string memory _tokenURI
    ) public payable {
        // get total NFT token supply
        uint256 supply = totalSupply();
        // check if contract is on pause
        require(!paused);
        require(_mintAmount > 0);
        require(_mintAmount <= maxMintAmount);
        require(supply + _mintAmount <= maxSupply);

        if (msg.sender != owner()) {
            // minting is free for first 200 request after which payment is required
            if (mintCount >= 200) {
                require(msg.value >= cost * _mintAmount);
            }
        }

        // set metada url
        setBaseURI(_tokenURI);

        // execute mint
        for (uint256 i = 0; i < _mintAmount; i++) {
            uint256 newTokenID = _tokenIds.current();
            _safeMint(_to, newTokenID);
            _tokenIds.increment();
        }
    }

    // breeding function(inflation) combine two tokens to get new token breed
    function breed(
        uint256 dragons1,
        uint256 dragons2,
        string memory _tokenURI
    ) public payable {
        require(_isApprovedOrOwner(msg.sender, dragons1));
        require(_isApprovedOrOwner(msg.sender, dragons2));

        uint256 supply = totalSupply();
        uint256 _mintAmount = 1;
        require(!paused);
        require(_mintAmount > 0);
        require(_mintAmount <= maxMintAmount);
        require(supply + _mintAmount <= maxSupply);

        setBaseURI(_tokenURI);

        // check if user owns scale token
        uint256 _value = 950 * 10**18;
        scaleBurn(_value);

        uint256 newTokenID = _tokenIds.current();
        //  issue new nft
        _safeMint(msg.sender, newTokenID);
        // send scale to user
        //  mintScale(msg.sender, 950);
        _tokenIds.increment();
    }

    // burn dragons(deflation) burn 3 dragons to get one new dragon token
    function burn(uint256[] memory _dragons, string memory _tokenURI) public {
        // require tokenids to be 3
        require(_dragons.length == 3);

        // check if addresse is token owner and execute burn for all 3 tokens
        for (uint256 i; i < _dragons.length; i++) {
            require(_isApprovedOrOwner(msg.sender, _dragons[i]));
            _burn(_dragons[i]);
        }

        // check if user owns scale token
        uint256 _value = 1000 * 10**18;
        scaleBurn(_value);

        //  mintScale(msg.sender, 1000);
        // mint one new token after burn
        mint(msg.sender, 1, _tokenURI);
    }

    // calculate total time since user stake function
    function calculateYieldTime(address user) public view returns (uint256) {
        uint256 end = block.timestamp;
        uint256 totalTime = end - startTime[user];
        return totalTime;
    }

    // calcukate amount of token user is to recieve
    function calculateYieldTotal(address user) public view returns (uint256) {
        uint256 time = calculateYieldTime(user) * 10**18;
        uint256 rate = 86400;
        uint256 totalDays = time / rate;
        uint256 recieveTokens = (10 * 10**18 * totalDays) / 10**18;
        return recieveTokens;
    }

    // yield/unstake nft to recieve scale token function
    function unstake() public {
        require(has_deposited[msg.sender], "No tokens to withdarw");
        require(
            has_deposited[msg.sender] = true,
            "you cant withdarw more multiple tomes"
        );

        // reward user with scale token
        scaleReward(msg.sender);
        // transfer users nft back to wallet
        _transfer(address(this), msg.sender, deposited_tokens[msg.sender]);
        //    update mapping record
        has_deposited[msg.sender] = false;
    }

    // scale reward function
    function scaleReward(address beneficiary) public {
        uint256 reward = calculateYieldTotal(beneficiary);
        mintScale(msg.sender, reward);
    }

    // get tokens owned by address
    function walletofNFT(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    //functions below can only be executed by owner

    // set or update mint cost/price
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    // set or update max number of mint per mint call
    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    // set metadata url function
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    // set metadata base extention
    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    // pause contract
    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    // claim/withdraw function

    function claim() public onlyOwner {
        // get contract total balance
        uint256 balance = address(this).balance;
        // begin withdraw based on address percentage

        // 40%
        payable(_archie).transfer((balance / 100) * 40);
        // 40%
        payable(_dani).transfer((balance / 100) * 40);
        // 10%
        payable(_nate).transfer((balance / 100) * 10);
        // 10%
        payable(_community).transfer((balance / 100) * 10);
    }
}
