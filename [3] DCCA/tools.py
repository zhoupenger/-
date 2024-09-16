import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def DCCA(x, y, s):
    """
    计算Detrended Cross-Correlation Analysis (DCCA) coefficients.
    
    Parameters:
    x, y: Arrays of time series data
    s: Window size
    
    Returns:
    rho_DCCA: DCCA coefficient
    F_DCCA: Covariance of detrended series
    F_DFA_X, F_DFA_Y: DFA of x and y series, respectively
    """
    # X和Y必须是同样长度的
    assert len(x) == len(y), "Time series must be the same length"
    
    x = np.asarray(x)
    y = np.asarray(y)
    
    # 标准化并且去趋势化
    X = np.cumsum(x - np.mean(x))
    Y = np.cumsum(y - np.mean(y))
    
    # 算法将处理后的时间序列划分为大小相等的窗口
    N = len(x) - s + 1
    
    F_DCCA = 0
    F_DFA_X = 0
    F_DFA_Y = 0
    
    for k in range(N):
        # 滑动窗口
        X_win = X[k:k+s]
        Y_win = Y[k:k+s]
        
        # 对于每个窗口，算法独立地拟合一个线性趋势线（通过一次多项式拟合）
        # deg为1进行线性拟合，返回[a, b]，对应于最佳拟合直线 y = ax + b 的斜率（a）和截距（b）。
        p_X = np.polyfit(np.arange(1, s+1), X_win, 1)
        p_Y = np.polyfit(np.arange(1, s+1), Y_win, 1)
        
        # Detrend 
        # polyval用于评估多项式的值
        X_detrend = X_win - np.polyval(p_X, np.arange(1, s+1)) # 拟合多项式预测的趋势值集合
        Y_detrend = Y_win - np.polyval(p_Y, np.arange(1, s+1))

        # 这种去趋势的步骤关键在于消除线性趋势对数据的影响，使分析可以集中在数据的波动性质上，而不是趋势上
        
        # 计算去趋势化时间序列的协方差(F_DCCA)，衡量波动是否同步
        F_DCCA += np.sum(X_detrend * Y_detrend) / (s - 1)
        # 计算去趋势化时间序列的方差(F_DFA_X 和 F_DFA_Y)，衡量波动的大小
        F_DFA_X += np.sum(X_detrend**2) / (s - 1)
        F_DFA_Y += np.sum(Y_detrend**2) / (s - 1)
    
    F_DCCA /= N
    F_DFA_X = np.sqrt(F_DFA_X / N)
    F_DFA_Y = np.sqrt(F_DFA_Y / N)
    
    # 最终结果用于计算DCCA系数（rho_DCCA）
    rho_DCCA = F_DCCA / (F_DFA_X * F_DFA_Y) # peraogram correlation coefficient
    
    return rho_DCCA, F_DCCA, F_DFA_X, F_DFA_Y


def show_DCCA_heatmap(cleaned_log_returns, window_size):

    # 计算所有国家对的DCCA系数
    countries = ['IT', 'RU', 'FR', 'UK', 'DE', 'US', 'CA', 'CN', 'JP']
    #window_size = 30
    dcca_results = {}

    for i in range(len(countries)):
        for j in range(i+1, len(countries)):
            country1 = countries[i]
            country2 = countries[j]
            rho_dcca, _, _, _ = DCCA(cleaned_log_returns[country1].values,
                                 cleaned_log_returns[country2].values,
                                 window_size)
            dcca_results[(country1, country2)] = rho_dcca


    countries = list(set([country for pair in dcca_results.keys() for country in pair]))
    corr_matrix = pd.DataFrame(index=countries, columns=countries, data=np.nan)

    # 填充DataFrame的对应元素
    for (country1, country2), rho_dcca in dcca_results.items():
        corr_matrix.loc[country1, country2] = rho_dcca
        corr_matrix.loc[country2, country1] = rho_dcca

    np.fill_diagonal(corr_matrix.values, 1)

    # 指定的顺序
    countries_order = ['US', 'CA', 'FR', 'DE', 'IT', 'JP', 'UK', 'CN', 'RU']

    # 重新排序DataFrame的行和列以匹配给定的顺序
    corr_matrix_ordered = corr_matrix.reindex(index=countries_order, columns=countries_order)

    #print(corr_matrix_ordered)

    # 创建遮罩以仅显示上三角矩阵
    mask = np.triu(np.ones_like(corr_matrix_ordered, dtype=bool))

    plt.figure(figsize=(10, 8))
    sns.heatmap(corr_matrix_ordered, mask=mask, annot=True, cmap='coolwarm', fmt=".2f", square=True)
    plt.title("DCCA Coefficients Heatmap with window size = {}".format(window_size))
    plt.xticks(rotation=45)

    plt.show()


# 假设Tf是股票时间序列数据的numpy数组，每列代表一个股票，每行代表一个时间点
# s是DCCA的滑动窗口大小
# w是计算DCCA时使用的子窗口大小
def compute_dcca_distances(Tf, s, w):
    T, n = Tf.shape  # 总股票数量和时间点数量

    rho_DCCA_matrixdist = np.full((n, n, T - w + 1), np.nan) # DCCA系数矩阵，考虑距离度量
    rho_DCCA_matrixnodist = np.full((n, n, T - w + 1), np.nan) # DCCA系数矩阵，不考虑距离度量

    # 循环计算每对股票
    for i in range(n):
        for j in range(i+1, n):
            # 选择两个股票
            stock1 = Tf[:, i]
            stock2 = Tf[:, j]

            # 在数据上滑动窗口
            for t in range(T - w + 1):
                # 选择当前窗口的数据
                x = stock1[t:t+w]
                y = stock2[t:t+w]
                
                rho, _, _, _ = DCCA(x, y, s)

                # 计算DCCA系数与DCCA距离
                rho_DCCA_matrixdist[i, j, t] = np.sqrt(2 * (1 - rho))
                rho_DCCA_matrixnodist[i, j, t] = rho

                
    '''
    # 检查NaN值
    nan_mask = np.isnan(rho_DCCA_matrixdist)
    nan_coords = np.where(nan_mask)

    if nan_coords[0].size == 0:
        print('no NaN found')
    else:
        for k in range(nan_coords[0].size):
            print(f'NaN detected for Stock {nan_coords[0][k]} and Stock {nan_coords[1][k]} at time {nan_coords[2][k]}')
    '''
    
    return rho_DCCA_matrixdist, rho_DCCA_matrixnodist