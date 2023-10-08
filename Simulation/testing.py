import random

def randomly_distribute(n, j):
    if n < j:
        raise ValueError("The value n should be greater than or equal to j.")
    
    distribution = random.sample(range(1, n), j - 1)
    distribution.sort()
    distribution.append(n - sum(distribution))
    
    return distribution

n = 100   # Total value to be distributed
j = 5     # Number of elements to distribute among

result = randomly_distribute(n, j)
print(result)