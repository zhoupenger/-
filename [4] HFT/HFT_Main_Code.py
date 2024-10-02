import pandas as pd
import numpy as np
from scipy import stats

import sys
sys.path.append('/Users/syesw/Desktop/My_Code_Project/Fintech-Paper/[4] HFT/')

nasdaq_hft = pd.read_parquet('Data/parquet/nasdaqhft_df.parquet')

# 数据清洗和处理
#nasdaq_hft['time'] = nasdaq_hft['time']/1000 # 转换时
#nasdaq_hft['date'] = pd.to_datetime(nasdaq_hft['date'], format='%Y%m%d') # 转换日期

# 统计交易量、买卖订单失衡度等
volume_by_stock_type = nasdaq_hft.groupby(['symbol', 'date', 'type'])['shares'].sum().reset_index()

# 如果需要进行winsorization (限制异常值)
def winsorize_series(s, limits):
    return stats.mstats.winsorize(s, limits=limits)

#nasdaq_hft['Variable_Winsorized'] = nasdaq_hft.groupby('Symbol')['Variable'].transform(lambda x: winsorize_series(x, limits=(0.01, 0.01)))

# 如果要对变量进行去均值化
#grouped = nasdaq_hft.groupby('Symbol')['Variable']
#nasdaq_hft['Variable_Demeaned'] = nasdaq_hft['Variable'] - grouped.transform('mean')


# 结合数据集
bidask = pd.read_parquet('Data/parquet/bidask_df.parquet')
option_metrics1 = pd.read_parquet('Data/parquet/optionmetrix1_df.parquet')
option_metrics2 = pd.read_parquet('Data/parquet/optionmetrix2_df.parquet')
option_metrics = pd.concat([option_metrics1, option_metrics2])

nasdaq_hft = nasdaq_hft.merge(bidask, on=['symbol', 'date']).merge(option_metrics, on=['symbol', 'date'])

print(nasdaq_hft.head())
exit()

# 计算控制变量
nasdaq_hft['Option_Dollar_Volume'] = nasdaq_hft['Volume'] * nasdaq_hft['MidQuote']

# 你将需要使用statsmodels等库来实现回归分析
import statsmodels.formula.api as smf

result = smf.ols(formula='DependentVariable ~ IndependentVariables', data=nasdaq_hft).fit()
print(result.summary())

# 导出结果
nasdaq_hft.to_csv('final_dataset.csv', index=False)