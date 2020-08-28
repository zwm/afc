import os
import shutil
import math


fref            = 26            # MHz
flo_start       = 2400          # 2.4G
flo_end         = 2500          # 2.5G
f_fvco_list     = 'fvco.txt'

fdir_log        = 'E:\YC1308\LogGen'
f_cfg           = 'cfg.txt'
f_m19           = 'ncntr_m19.txt'
f_m64           = 'ncntr_m64.txt'

# global var
fvco_list = []
flo_info_list = []

# divr_calc
def divr_calc (trx, flo):
    # fvco calc
    if trx:
        fvco = flo*4/3
    else:
        fvco = flo*2
    # divr_int
    divr = fvco/2/fref
    divr_int    = math.floor(divr)
    divr_frac   = divr - divr_int
    # return
    return fvco, divr_int, divr_frac

# frac2hex
def frac2hex (frac, bw):
    # init
    hc = 0
    vc = 1
    # calc
    for i in range(bw):
        vc = vc/2
        if frac >= vc:
            frac = frac - vc
            hc = (hc << 1) + 1
        else:
            frac = frac - 0
            hc = (hc << 1) + 0
    return hc

# cfg_gen
def cfg_gen (case_num, cfg_list, m):
    divr        = cfg_list[2]*256 + (cfg_list[3] >> 16)
    trx         = cfg_list[0]
    vcoband     = cfg_list[4]
    with open(f_cfg, 'w') as f:
        f.write('vcoband                 %d\n'%(  vcoband       ));
        f.write('trx                     %d\n'%(  trx           ));
        f.write('divr                    %04x\n'%(  divr        ));
        f.write('afc_cg_auto             %d\n'%(  1             ));
        f.write('rg_forceband_en         %d\n'%(  0             ));
        f.write('rg_vco_capband          %d\n'%(  0             ));
        f.write('rg_afc_vcostable_time   %d\n'%(  case_num%4    ));
        f.write('rg_afc_cnt_time         %d\n'%(  m             ));
        f.write('rg_aac_bypass           %d\n'%(  1             ));
        f.write('rg_aac_stable_time      %d\n'%(  0             ));
        f.write('rg_aac_cbandrange       %d\n'%(  0             ));
        f.write('rg_ini_ibsel_rx         %d\n'%(  5             ));
        f.write('rg_ini_ibsel_tx         %d\n'%(  9             ));

# aac_gen
def aac_gen (case_num, cfg_list, m, ibsel_rx, ibsel_tx):
    divr        = cfg_list[2]*256 + (cfg_list[3] >> 16)
    trx         = cfg_list[0]
    vcoband     = cfg_list[4]
    with open(f_cfg, 'w') as f:
        f.write('vcoband                 %d\n'%(  vcoband       ));
        f.write('trx                     %d\n'%(  trx           ));
        f.write('divr                    %04x\n'%(  divr        ));
        f.write('afc_cg_auto             %d\n'%(  1             ));
        f.write('rg_forceband_en         %d\n'%(  0             ));
        f.write('rg_vco_capband          %d\n'%(  0             ));
        f.write('rg_afc_vcostable_time   %d\n'%(  case_num%4    ));
        f.write('rg_afc_cnt_time         %d\n'%(  m             ));
        f.write('rg_aac_bypass           %d\n'%(  0             ));
        f.write('rg_aac_stable_time      %d\n'%(  case_num%4    ));
        f.write('rg_aac_cbandrange       %d\n'%(  case_num%4    ));
        f.write('rg_ini_ibsel_rx         %d\n'%(  ibsel_rx      ));
        f.write('rg_ini_ibsel_tx         %d\n'%(  ibsel_tx      ));

# data format: trx, fvco, div_int, div_frac, vcoband
for i in range(2):
    for j in range(flo_end - flo_start + 1):
        trx = i
        div_list = [0, 0, 0, 0, 0]
        flo = flo_start + j
        div_ret = divr_calc(trx, flo)
        div_list[0] = trx
        div_list[1] = div_ret[0]
        div_list[2] = div_ret[1]
        div_list[3] = frac2hex(div_ret[2], 24)
        flo_info_list.append(div_list)
        print("trx: %d, flo: %d, fvco: %f, divr_int: %d, divr_frac: %06x"%(trx, flo, div_list[1], div_list[2], div_list[3]))

# read fvco
with open(f_fvco_list, 'r') as f:
    for line in f:
        line = line.strip()
        line = float(line)
        fvco_list.append(line)
        print("%f"%line)

# update vcoband
for k in range(len(flo_info_list)):
    fvco = flo_info_list[k][1]
    err_min = 999999999
    err_min_idx = 0
    for i in range(len(fvco_list)):
        err_cur = abs(fvco - fvco_list[i])
        if err_cur < err_min:
            err_min = err_cur
            err_min_idx = i
    if err_min_idx >= 128:
        err_min_idx = err_min_idx - 128
    flo_info_list[k][4] = err_min_idx
    print('fvco: %f, err_min: %f, vcoband: %d'%(fvco, err_min, err_min_idx))

# init dir
curr_dir = os.getcwd()
if os.path.exists(fdir_log):
    shutil.rmtree(fdir_log)
os.mkdir(fdir_log)
os.chdir(fdir_log)
# gen log
for k in range(2):
    for i in range(len(flo_info_list)):
        idx = k*1000 + i
        # enter case dir
        case_name = 'case%d'%idx
        os.mkdir(case_name)
        os.chdir(case_name)
        # m
        if k == 0:
            m = 18
        elif k == 1:
            m = 63
        # cfg_gen
        cfg_gen(idx, flo_info_list[i], m)
        # leave case dir
        os.chdir('../')

# aac
for i in range(32):
    idx = 2000 + i
    # enter case dir
    case_name = 'case%d'%idx
    os.mkdir(case_name)
    os.chdir(case_name)
    m = 63
    if (i<16):
        ibsel_rx = i%16
        ibsel_tx = 0
        fl = flo_info_list[i]

    else:
        ibsel_rx = 0
        ibsel_tx = i%16;
        fl = flo_info_list[128 + i]
    # log_gen
    aac_gen(idx, fl, m, ibsel_rx, ibsel_tx)
    # leave case dir
    os.chdir('../')

# change dir
os.chdir(curr_dir)
## ncntr copy
#shutil.copyfile(f_m19, fdir_log)
#shutil.copyfile(f_m64, fdir_log)




