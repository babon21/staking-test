import pytest
from brownie import Staking, Contract, TokenMock, chain, reverts


@pytest.fixture(scope='module')
def deployer(accounts):
    return accounts[0]


@pytest.fixture(scope='function')
def staking(deployer, token):
    baseApy = 150
    bonusApy = [10, 20, 30, 40, 50, 60]

    return Staking.deploy(token.address, baseApy, bonusApy, {'from': deployer})


@pytest.fixture
def token(deployer):
    return TokenMock.deploy('DAI', 'DAI', {'from': deployer})


@pytest.fixture(scope='function')
def amount(staking, accounts, token):
    amount = 1000 * 10 ** token.decimals()
    reserve = accounts[1]
    token.mint(reserve, amount)
    token.approve(staking, amount, {'from': reserve})
    return amount


def test_change_owner(staking, accounts):
    old = staking.owner()
    new = accounts[1]

    staking.transferOwnership(new)
    cur = staking.owner()

    assert old != new
    assert cur == new


def test_add_to_pool(staking, token, amount, accounts):
    before = token.balanceOf(staking)
    staking.addToPool(amount, {'from': accounts[1]})
    after = token.balanceOf(staking)
    assert before == 0
    assert after == amount


def test_unstake_ok(staking, accounts, amount, token):
    staking.addToPool(500, {'from': accounts[1]})
    tx = staking.stake(100, 7, {'from': accounts[1]})
    before = token.balanceOf.call(accounts[1])
    chain_sleep(10)
    tx2 = staking.unstake(0, {'from': accounts[1]})
    # print(tx2.events[1]['account'])
    # print(tx2.events[1]['stakingId'])
    # print(tx2.events[1]['unstakeDate'])
    # print(tx2.events[1]['shares'])
    after = token.balanceOf.call(accounts[1])
    assert tx2.events[1]['shares'] == after - before


def test_unstake_fail_stake_not_ended(staking, accounts, amount, token):
    staking.addToPool(500, {'from': accounts[1]})
    staking.stake(100, 7, {'from': accounts[1]})
    token.balanceOf.call(accounts[1])
    with reverts():
        staking.unstake(0, {'from': accounts[1]})

def test_unstake_fail_auth(staking, accounts, amount, token):
    staking.addToPool(500, {'from': accounts[1]})
    staking.stake(100, 7, {'from': accounts[1]})
    token.balanceOf.call(accounts[1])
    chain_sleep(10)
    with reverts():
        staking.unstake(0)

def test_unstake_repeat_fail(staking, accounts, amount, token):
    staking.addToPool(500, {'from': accounts[1]})
    staking.stake(100, 7, {'from': accounts[1]})
    token.balanceOf.call(accounts[1])
    chain_sleep(10)
    staking.unstake(0, {'from': accounts[1]})
    with reverts():
        staking.unstake(0, {'from': accounts[1]})

def test_stake_fail_not_enough_tokens(staking, accounts, amount, token):
    with reverts():
        staking.stake(100, 7, {'from': accounts[1]})

def test_withdraw_tokens(staking, accounts, amount, token):
    staking.addToPool(500, {'from': accounts[1]})
    before = token.balanceOf.call(accounts[0])
    contract_balance = token.balanceOf(staking.address)
    staking.withdrawTokens()
    after = token.balanceOf.call(accounts[0])
    assert before + contract_balance == after


def chain_sleep(days):
    chain.sleep(days * 60 * 60 * 24 + 10)
