import math
import json
import random
import secrets
from names import get_first_name
from powerlaw import Power_Law as powerlaw

from web3 import Web3

# connect to the local ethereum blockchain
provider = Web3.HTTPProvider('http://127.0.0.1:8545')
w3 = Web3(provider)
# check if ethereum is connected
if not w3.is_connected():
    exit("Can't Connect to Ethereum")

# TODO: replace the address with your contract address (!very important)
deployed_contract_address = '0x46E19b2c071e0796B641529DC96a29C21f902e41'

# path of the contract json file. edit it with your contract json file
compiled_contract_path = "build/contracts/Payment.json"
with open(compiled_contract_path) as file:
    contract_json = json.load(file)
    contract_abi = contract_json['abi']
contract = w3.eth.contract(address=deployed_contract_address, abi=contract_abi)

'''
# Calling a contract function createAcc(uint,uint,uint)
txn_receipt = contract.functions.createAcc(1, 2, 5).transact({'txType':"0x3", 'from':w3.eth.accounts[0], 'gas':2409638})
txn_receipt_json = json.loads(w3.to_json(txn_receipt))
print(txn_receipt_json) # print transaction hash

# print block info that has the transaction)
print(w3.eth.get_transaction(txn_receipt_json)) 

# Call a read only contract function by replacing transact() with call()
'''

# ------------------------ Helper Functions ------------------------


def random_exponential(lambd):
    ''' Generates a random number from an exponential distribution with rate parameter lambd. '''
    u = random.uniform(0, 1)
    return int(round(-math.log(1 - u) * lambd))


def dfs(node, adj_list, visited):
    # Add the current node to the set of visited nodes
    visited.add(node)
    # Recursively visit all neighbors of the current node
    for neighbor in adj_list[node]:
        if neighbor not in visited:
            dfs(neighbor, adj_list, visited)


def is_connected(adj_list):
    # Initialize a set to keep track of visited nodes
    visited = set()
    # Perform depth-first search from an arbitrary node
    dfs(0, adj_list, visited)
    # Check if all nodes were visited
    return len(visited) == len(adj_list)


#  ------------------------ Network Graph Generation ------------------------


# set the parameters
alpha = 2.75  # parameter of the power-law dist
participants = 100  # no. of nodes in the network
dist = []  # degree distribution from powerlaw


# generate a valid power law distribution, valid means the degree of each node belongs to [1, participants)
while True:
    dist = powerlaw(xmin=1, parameters=[alpha]).generate_random(participants)  # generate the distribution
    dist = [round(val) for val in dist]

    if all([val > 0 and val < participants for val in dist]):
        break  # valid dist

adj_list = []


# generate the adjacency list
while True:
    adj_list = [[] for _ in range(participants)]

    for node in range(participants):
        possible_neigh = [_ for _ in range(participants)]

        while len(adj_list[node]) < dist[node]:
            random_node = secrets.choice(possible_neigh)

            if random_node != node and random_node not in adj_list[node]:
                adj_list[node].append(random_node)
                adj_list[random_node].append(node)
            else:
                possible_neigh.remove(random_node)

    if is_connected(adj_list):
        break

#  ------------------------ Port the Network Graph to the Blockchain ------------------------

# register the users
for node_id in range(participants):
    print(f"\rRegistering user {node_id+1}", end="")
    txn_receipt = contract.functions.registerUser(node_id, get_first_name()).transact({'from': w3.eth.accounts[0]})
    json.loads(w3.to_json(txn_receipt))

print(f'\r{participants} Users Registered   ')

# create the joint accounts
for user1 in range(participants):
    print(f"\rProcessing Joint Accounts for user {user1}", end="")
    for user2 in adj_list[user1]:
        if user2 < user1:
            continue
        txn_receipt = contract.functions.createAcc(user1, user2, random_exponential(10)).transact({'from': w3.eth.accounts[0]})

print(f'\r{sum(dist)} Joint Accounts Created                  \n')


# ------------------------ Simulating Transactions ------------------------

print('Simulating 1000 transactions\n')
lst = []

for txnNo in range(1, 1001):
    # randomly choose the sender and receiver
    sender = random.randint(1, participants) - 1
    receiver = random.randint(1, participants) - 1
    while sender == receiver:
        receiver = random.randint(1, participants) - 1

    txn_receipt = contract.functions.sendAmount(sender, receiver, 1).transact({'from': w3.eth.accounts[0]})
    json.loads(w3.to_json(txn_receipt))

    print(f'\rProgress: {txnNo/10}% ', end='')

    if txnNo % 100 == 0:
        txn_receipt = contract.functions.successfulCount().call()
        successful = int(json.loads(w3.to_json(txn_receipt)))
        print(
            f'\rCompleted: {txnNo}, Successful Ratio: {round(successful/txnNo, 3)}')
        lst.append(round(successful/txnNo, 3))
