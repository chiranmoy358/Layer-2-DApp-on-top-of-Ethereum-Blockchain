// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Payment {
    uint public participants; // number of participants (users) in the network
    uint public successfulCount;
    uint public transactionCount;
    uint[][] adjList;

    mapping(string => uint) balance; // balance of id1 in the joint account "id1->id2"
    mapping(uint => string) userIDString; // string format of a uint
    mapping(uint => string) usernames;  

    event TransactionLog(uint sender, uint receiver, bool isSuccessful, string txnPath);

    function registerUser(uint user_id, string memory username) public {
        userIDString[user_id] = uintToString(participants);
        usernames[user_id] = username;
        participants++;

        // Add an empty array to the adjacency list
        uint[] memory arr;
        adjList.push(arr);
    }


    function createAcc(uint user_id_1, uint user_id_2, uint accBalance) public {
        require(user_id_1 < participants && user_id_2 < participants, "Invalid User ID");
        require(accBalance >= 0, "Invalid Joint Account Balance");

        // check if the connection already exists
        for(uint i=0; i<adjList[user_id_1].length; i++) {
            if(adjList[user_id_1][i] == user_id_2)
                revert("Joint Account Exists");
        }

        // Update the adjacency list
        adjList[user_id_1].push(user_id_2);
        adjList[user_id_2].push(user_id_1);

        // Add the balances in the joint account
        balance[getKey(user_id_1, user_id_2)] = accBalance/2; 
        balance[getKey(user_id_2, user_id_1)] = accBalance/2; 
    }


    function sendAmount(uint sender, uint receiver, uint amt) public {
        require(sender < participants && receiver < participants, "Invalid User ID");
        require(amt > 0, "Invalid Amount");
        transactionCount++;

        uint index = 0;
        uint nextIndex = 1;
        uint[] memory queue = new uint[](participants);
        bool[] memory visited = new bool[](participants);
        uint[] memory parent = new uint[](participants);

        queue[0] = sender;
        visited[sender] = true;
        parent[sender] = sender;

        // do a bfs and find the shortest path
        while(index < nextIndex) {
            uint node = queue[index++];

            for(uint i=0; i<adjList[node].length; i++) {
                uint neigh = adjList[node][i];
                if(visited[neigh]) // neigh already visited
                    continue;

                string memory key = getKey(node, neigh);
                if(balance[key] < amt) // check if the edge can support the transaction
                    continue;
                
                visited[neigh] = true;
                parent[neigh] = node;
                queue[nextIndex++] = neigh; // adding to the queue

                if(neigh == receiver) {
                    nextIndex = 0; // receiver reached, quit bfs
                    break; 
                }
            }
        }

        // no valid path
        if(!visited[receiver]) {
            emit TransactionLog(sender, receiver, false, "");
            return;
        }

        // Backtracking using the parent array and update the joint accounts
        uint to = receiver;
        string memory path = userIDString[receiver];

        while(to != sender) {
            uint from = parent[to];
            string memory debit = getKey(from, to);
            string memory credit = getKey(to, from);

            balance[debit] -= amt;
            balance[credit] += amt;

            path = string(abi.encodePacked(userIDString[from], "->", path));
            to = from;
        }

        emit TransactionLog(sender, receiver, true, path);
        successfulCount++;
    }


    function closeAccount(uint user_id_1, uint user_id_2) public {
        require(user_id_1 < participants && user_id_2 < participants, "Invalid User ID");
        uint i;

        // Delete user_id_2 from the adjList of user_id_1
        for(i=0; i<adjList[user_id_1].length; i++) {
            if(adjList[user_id_1][i] == user_id_2)
                break;
        }
        adjList[user_id_1][i] = adjList[user_id_1][adjList[user_id_1].length-1];
        adjList[user_id_1].pop();

        // Delete user_id_1 from the adjList of user_id_2
        for(i=0; i<adjList[user_id_2].length; i++) {
            if(adjList[user_id_2][i] == user_id_1)
                break;
        }
        adjList[user_id_2][i] = adjList[user_id_2][adjList[user_id_2].length-1];
        adjList[user_id_2].pop();

        // Delete mappings from balance map
        string memory edge1 = getKey(user_id_1, user_id_2);
        string memory edge2 = getKey(user_id_2, user_id_1);

        delete balance[edge1];
        delete balance[edge2];
    }

    // ---------------------- Helper Functions ----------------------

    // lists the nodes with whom, this node has a joint account and returns as space separated string
    function jointAccounts(uint node) public view returns(string memory) {
        require(node < participants, "Invalid User ID");
        string memory list;

        for(uint i=0; i<adjList[node].length; i++) {
            list = string(abi.encodePacked(list, " ", userIDString[adjList[node][i]]));
        }

        return list;
    }

    // lists the balance of a user in various joint accounts, and returns as a space separated string
    function balanceDistribution() public view returns(string memory) {
        string memory list;

        for(uint i=0; i<participants; i++) {
            uint accBalance = 0;

            for(uint j=0; j<adjList[i].length; j++) {
                accBalance += balance[getKey(i, adjList[i][j])];
            }

            list = string(abi.encodePacked(list, " ", uintToString(accBalance)));
        }

        return list;
    }

    // get the key for the balance mapping in the format "{id1}->{id2}"
    function getKey(uint id1, uint id2) internal view returns(string memory) {
        return string(abi.encodePacked(userIDString[id1], "->", userIDString[id2]));
    }

    // Converts unsigned integer to string
    function uintToString(uint _i) internal pure returns(string memory str) {
        if (_i == 0) return "0";
        uint j = _i;
        uint length;

        while (j != 0) {
            length++;
            j /= 10;
        }

        bytes memory bstr = new bytes(length);
        uint k = length;

        while (_i != 0) {
            k--;
            bstr[k] = bytes1(uint8(48 + _i % 10));
            _i /= 10;
        }

        return string(bstr);
    }
}