from sklearn.linear_model import LinearRegression
import numpy as np
import pickle


def load_pkl(pkl_name):
    '''
    Args:
        pkl_name (string): path for pickle.
    
    Returns:
        (dict): including following structure
            `raw time-series data` (N, 32, 4):
                'train_data', 'val_data', 'test_data'
            `gasf data` (N, 32, 32, 4):
                'train_gaf', 'val_gaf', 'test_gaf'
            `label data` (N, 3):
                'train_label', 'val_label', 'test_label',
            `one-hot label data` (N, 9):
                'train_label_arr', 'val_label_arr', 'test_label_arr'
    '''
    # load data from data folder
    with open(pkl_name, 'rb') as f:
        data = pickle.load(f)
    return data