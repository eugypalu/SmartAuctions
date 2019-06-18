from web3.auto import w3


def main():
    nonce = input("Insert nonce \n")
    bid = input("insert bid \n")
    try:
        nonce = int(nonce)
        bid = int(bid)
        keccakHash = getKeccak256(nonce, bid)
        print(keccakHash)
        return keccakHash
    except ValueError:
        print("nonce and bid must be int \n")
        return -1
        
        

def getKeccak256(_nonce, _bid):
    result = w3.soliditySha3(['uint256', 'uint256'], [_nonce, _bid])
    return result.hex()

if __name__ == "__main__":
    loop = -1
    while loop == -1:
        loop = main()




"""
keccakHash = w3.soliditySha3(['uint256', 'uint256'], [123, 100])
print(keccakHash.hex())
"""