# prime table generator
import sympy

def find(n):
    if n == 1:
        return 0
    while True:
        if sympy.isprime(n):
            return n
        n += 1

for i in range(64):
    print('{}, '.format(find(1 << i)))
    # print('1 << {} -> {} '.format(i, find(1 << i)))
