from copy import deepcopy
from random import randint

# Parameters
# monotonicity
weight = [[pow(3, 1),  1,  1,  1],
          [pow(3, 2),  3,  3,  3],
          [pow(3, 3),  9,  9,  9],
          [pow(3, 5), pow(3, 6), pow(3, 7),  pow(3, 8)]]

# smoothness
k = 1

# empty tiles
cdef float EMPTY_WEIGHT = 270.0

# My 2048 Operation
# Merge Tiles
def merge(cells):
    if len(cells) <= 1:
        return cells

    i = 0

    while i < len(cells) - 1:
        if cells[i] == cells[i+1]:
            cells[i] *= 2

            del cells[i+1]

        i += 1


def move_up(state):
    r = range(4)

    moved = False

    for j in range(4):
        cells = []

        for i in r:
            cell = state[i][j]

            if cell != 0:
                cells.append(cell)

        merge(cells)

        for i in r:
            value = cells.pop(0) if cells else 0

            if state[i][j] != value:
                moved = True

            state[i][j] = value

    return moved


def move_down(state):
    r = range(3, -1, -1)

    moved = False

    for j in range(4):
        cells = []

        for i in r:
            cell = state[i][j]

            if cell != 0:
                cells.append(cell)

        merge(cells)

        for i in r:
            value = cells.pop(0) if cells else 0

            if state[i][j] != value:
                moved = True

            state[i][j] = value

    return moved


def move_left(state):
    r = range(4)

    moved = False

    for i in range(4):
        cells = []

        for j in r:
            cell = state[i][j]

            if cell != 0:
                cells.append(cell)

        merge(cells)

        for j in r:
            value = cells.pop(0) if cells else 0

            if state[i][j] != value:
                moved = True

            state[i][j] = value

    return moved


def move_right(state):
    r = range(3, -1, -1)

    moved = False

    for i in range(4):
        cells = []

        for j in r:
            cell = state[i][j]

            if cell != 0:
                cells.append(cell)

        merge(cells)

        for j in r:
            value = cells.pop(0) if cells else 0

            if state[i][j] != value:
                moved = True

            state[i][j] = value

    return moved


def move(state, i):
    if i == 0:
        return move_up(state)
    if i == 1:
        return move_down(state)
    if i == 2:
        return move_left(state)
    if i == 3:
        return move_right(state)


# Return All the Empty Cells
def find_empty(state):
    cells = []

    for x in range(4):
        for y in range(4):
            if state[x][y] == 0:
                cells.append((x, y))

    return cells


# Return the number of empty tiles
cdef int num_empty(state):
    cdef cnt, x, y
    cnt = 0
    for x in range(4):
        for y in range(4):
            if state[x][y] == 0:
                cnt += 1
    return cnt


# Search
# heuristic function
cdef float heuristic(state):
    cdef float reward, max_tile
    cdef int i, j
    reward = 0
    max_tile = 0

    for i in range(4):
        for j in range(4):
            # monotonicity
            reward += weight[i][j] * state[i][j]
            # smoothness
            if i - 1 >= 0:
                reward -= k * abs(state[i][j] - state[i - 1][j])
            if i + 1 < 4:
                reward -= k * abs(state[i][j] - state[i + 1][j])
            if j - 1 >= 0:
                reward -= k * abs(state[i][j] - state[i][j - 1])
            if j + 1 < 4:
                reward -= k * abs(state[i][j] - state[i][j + 1])
            # empty tiles
            if state[i][j] == 0:
                reward += EMPTY_WEIGHT
            # find max tile
            if state[i][j] > max_tile:
                max_tile = state[i][j]
    # avoid max tile leaving
    if state[3][3] != max_tile and state[3][3] != 0:
        reward -= state[3][3] * weight[3][3]

    return reward


# expectimax search
cdef float expectimax(state, int depth, int is_max):
    cdef float v
    cdef int i
    cdef float total, avr
    cdef int cnt

    if depth == 0:
        return heuristic(state)
    if is_max:
         # avoid using float('-inf') in Cython
        v = -2147483648
        for i in range(4):
            new_state = deepcopy(state)
            if move(new_state, i):
                v = max(v, expectimax(new_state, depth-1, False))
        return v
    else:
        total = 0
        cnt = 0
        for cell in find_empty(state):
            new_state = deepcopy(state)
            new_state[cell[0]][cell[1]] = 2
            v = expectimax(new_state, depth-1, True)
            total += v
            cnt += 1
        avr = total/cnt
        return avr


# sample-expectimax search
cdef float sample_expectimax(state, int depth, int sample, int is_max):
    cdef float v, total, avr
    cdef int i
    cdef int cnt, num
    cdef float p

    if depth == 0:
        return heuristic(state)
    if is_max:
        p = 0.3
        # avoid using float('-inf') in Cython
        v = -2147483648
        for i in range(4):
            new_state = deepcopy(state)
            if move(new_state, i):
                v = max(v, sample_expectimax(new_state, depth-1, sample, False))
        return (1-p) * heuristic(state) + p * v
    else:
        total = 0
        cnt = 0
        cells = find_empty(state)
        num = len(cells)
        p = 1.0/num
        cell_to_search = []
        # Monte Carlo: random sampling
        if num > sample:
            for i in range(sample):
                cell_to_search.append(cells[randint(0, num-1)])
        else:
            cell_to_search = cells

        for cell in cell_to_search:
            new_state = deepcopy(state)
            new_state[cell[0]][cell[1]] = 2
            v = sample_expectimax(new_state, depth-1, sample, True)
            total += v
            cnt += 1
        avr = total/cnt
        return (1-p) * heuristic(state) + p * avr


# policy function
def policy(state):
    cdef int i
    cdef int num, depth, sample

    # be aware of deepcopy and []*4
    states = [deepcopy(state), deepcopy(state), deepcopy(state), deepcopy(state)]
    moved = [False]*4
    rewards = [-float("inf")]*4

    # 0: UP, 1:DOWN, 2:LEFT, 3:RIGHT
    for i in range(4):
        moved[i] = move(states[i], i)
        if moved[i]:
            num = num_empty(states[i])
            if num > 7:
                depth = 3
            elif num > 3:
                depth = 4
            elif num == 3:
                depth = 5
            else:
                depth = 6

            rewards[i] = expectimax(states[i], depth, False)
            #rewards[i] = sample_expectimax(states[i], depth, sample, False)

    return rewards.index(max(rewards))
