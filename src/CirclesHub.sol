pragma solidity ^0.4.10;

import "./CirclesToken.sol";

import "ds-token/token.sol";
import "ds-math/math.sol";

contract CirclesHub is DSMath {

    uint constant LIMIT_EPOCH = 3600;

    struct EdgeWeight {
        uint limit;
        uint value;
        uint lastTouched;
    }

    mapping (address => CirclesToken) public userToToken;
    mapping (address => address) public tokenToUser;

    mapping (address => bool) validators;

    mapping (address => mapping (address => EdgeWeight)) public edges;

    function time() returns (uint) { return block.timestamp; }

    // No exit allowed. Once you create a personal token, you're in for good.
    function join() {
        assert(address(userToToken[msg.sender]) == 0);
        var token = new CirclesToken(msg.sender);
        userToToken[msg.sender] = token;
        tokenToUser[address(token)] = msg.sender;
    }

    function register() {
        validators[msg.sender] = true;
    }

    // Trust does not have to be reciprocated. 
    // (e.g. I can trust you but you don't have to trust me)
    function trust(address node, bool yes, uint limit) {
        assert(address(tokenToUser[node]) != 0 || validators[node]);
        edges[msg.sender][node] = yes ? EdgeWeight(limit, 0, time()) : EdgeWeight(0, 0, 0);

    }

    // Starts with msg.sender then , 
    // iterates through the nodes list swapping the nth token for the n+1 token
    function transferThrough(address[] nodes, address[] tokens, uint wad) {

        uint tokenIndex = 0;

        address currentValidator;

        address prevNode;

        for (var x = 0; x < nodes.length; x++) {
            
            var node = nodes[x];

            var token = CirclesToken(tokens[tokenIndex]);

            if (currentValidator != 0) {
                prevNode = currentValidator;
                currentValidator = 0;
            }
            else {
                prevNode = token;
            }
            // edges[node][prevNode] 
            assert(edges[node][prevNode].lastTouched != 0);

            edges[node][prevNode].value = time() - edges[node][prevNode].lastTouched < LIMIT_EPOCH
                ? edges[node][prevNode].value + wad
                : wad;

            edges[node][prevNode].lastTouched = time();
            
            assert(edges[node][prevNode].limit >= edges[node][prevNode].value);

            if (validators[node]) {
                currentValidator = node;
            } else {
                
                token.transferFrom(msg.sender, node, wad);

                if (tokenIndex + 1 < tokens.length) {

                    var nextToken = CirclesToken(tokens[tokenIndex + 1]);
                    nextToken.transferFrom(node, msg.sender, wad);
                }
                tokenIndex++;
            } 
        }
    }
}
