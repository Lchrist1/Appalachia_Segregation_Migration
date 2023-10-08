#In this program, I will run a simulation of a series of segregation indices to demonstrate
#the relationship between unevenness and bias in the logan parman index.

#Consider a state with j counties indexed by i. 
#Each county has a population of n_i, of which w_i are white and b_i are black. 
#Correspondingly, the population of the state is defined as N=W+B, 
    #where W is the total white population and B is the total black population.
#Assume we observe the race of each citizen and their neighbors.
#For each county, the expected number of black citizens with at least one white neighbor is:
#e_i = b_i* (w_i-1/n_i-1)(w_i-2/n_i-2)
#For the state, we similarly define E= sum(e_i) over j counties.
#Furthermore, define the unevenness of the state as: 
#the sum of sum over j of |(w_i/W)-(b_i/B)| = PI

#First, we show a state with a perfectly uniform racial distribution,i.e. PI=0.

#Define a function that generates a random state of j counties, each with n population and a uniform racial distribution:
import random as rand
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

def random_state(n):
    #define the racial composition of the state randomly
    w_state= rand.random()
    #random number between 0.25 and 0.75
    w_state= w_state/2+0.25
    w_state= w_state*n
    ratio = w_state/n
    return(ratio)

def random_counties_uniform(population_left, counties, ratio):
     if population_left < 1:
        #drop last county
        counties = counties[:-1]
        return counties
     else:
        n_county = rand.sample(range(1,1000), 1)[0]
        w_county = n_county*ratio
        b_county = n_county-w_county
        population_left = population_left-n_county
        unevenness = abs(w_county/n_county-b_county/n_county)
        counties.append([w_county, b_county, n_county, ratio, unevenness])
        return random_counties_uniform(population_left, counties, ratio)
     
def random_counties_random(black_left, white_left, counties): 
     population_left = black_left+white_left
     if population_left < 1:
        #drop last county
        counties = counties[:-1]
        return counties
     else:
        n_county = rand.sample(range(1,1000), 1)[0]
        ratio = rand.random()/2+0.25
        w_county = round(n_county*ratio)
        b_county = n_county-w_county
        black_left = black_left-b_county
        white_left = white_left-w_county
        unevenness = abs(w_county/n_county-b_county/n_county)
        counties.append([w_county, b_county, n_county, ratio, unevenness])
        return random_counties_random(black_left, white_left, counties)
    
def random_counties_centered(black_left, white_left, counties, ratio):
     population_left = black_left+white_left
     W = ratio*10000
     B = 10000-W
     if population_left < 1:
        #drop last county
        counties = counties[:-1]
        return counties
     else:
        n_county = rand.sample(range(10,1000), 1)[0]
        county_ratio = ratio+rand.normalvariate(0,1)*ratio/3
        w_county = round(n_county*county_ratio)
        b_county = n_county-w_county
        black_left = black_left-b_county
        white_left = white_left-w_county
        unevenness = abs(w_county/W-b_county/B)
        expected_c = b_county*((w_county-1)/(n_county-1))*((w_county-2)/(n_county-2))
        if expected_c >0:
            actual = rand.randint(0, round(expected_c))
        else:
            actual = 0
        logan_parman = (expected_c-actual)/(expected_c-2)
        counties.append([w_county, b_county, n_county, county_ratio, unevenness, actual, expected_c, logan_parman])
        return random_counties_centered(black_left, white_left, counties, ratio)    

#manually calculate the expected number of black citizens with at least one white neighbor in the state
def expected_neighbor_state(N, ratio):
    W= N*ratio
    B= N-W
    E = B*((W-1)/(N-1))*((W-2)/(N-2))
    return E

#Repeat the process of generating a random state and calculating the two expected values 1000 times
def monte_carlo(n, type):
    data = []
    ratio = random_state(n)
    for i in range(0, 1000):
        ratio = random_state(n)
        counties = []
        if type == 'uniform':
            counties = random_counties_uniform(n, counties, ratio)
        else:
            if type == 'random':
                white = round(ratio*n)
                black = n-white
                counties = random_counties_random(black, white, counties)
            else:
                if type == 'centered':
                    white = round(ratio*n)
                    black = n-white
                    counties = random_counties_centered(black, white, counties, ratio)
        #convert to dataframe
        counties = pd.DataFrame(counties, columns=['w_county', 'b_county', 'n_county', 'ratio', 'unevenness', 'actual', 'expected_c', 'logan_parman'])
        #calculate the expected number of black citizens with at least one white neighbor
        #calculate the expected number of black citizens with at least one white neighbor in the state
        E = counties['expected_c'].sum()
        E_state = expected_neighbor_state(n, ratio)
        unevenness = counties['unevenness'].sum()
        logan_parman = counties['logan_parman'].mean()
        j = len(counties.index)
        #save the estimated E and E_state
        data.append([E, E_state, unevenness, j, logan_parman])
    return data

#Plot the results
def plot_results(simulation):
    #drop outliers (loganparman > 1)
    simulation = simulation[simulation['logan_parman']<1]
    simulation = simulation[simulation['logan_parman']>0]

    #plot logan parman against unevenness
    sns.scatterplot(x='unevenness', y='logan_parman', data=simulation)
    plt.show()

    #plot E_state against E
    sns.scatterplot(x='logan_parman', y='E_state', data=simulation)
    plt.show()


def main():
    n=10000
    type = 'centered'
    simulation = monte_carlo(n,type)
    simulation = pd.DataFrame(simulation)

    simulation.columns = ['E', 'E_state', 'unevenness', 'j', 'logan_parman']
    simulation['unevenness'] = simulation['unevenness']*0.5
    simulation['difference'] = simulation['E_state']-simulation['E']

    plot_results(simulation)

main()