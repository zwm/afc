// fsdb
`define DUMP_FSDB               1
//`define DUMP_ARRAY              1

//`define TEST_AFC

`define TEST_LOGEN


`define CASE_START              0
//`define CASE_START              201             // AFC RX: 0~201
//`define CASE_START              404             // AAC: 404~404+31
`define CASE_STOP               (404 + 31)

`define LOG_DIR                 "../log"
`define FILE_CASE_LIST          "./case_list"
`define FILE_CFG                "cfg.txt"
`define NCNTR_M19               "ncntr_m19.txt"
`define NCNTR_M64               "ncntr_m64.txt"
`define AFC_TOP                 tb_top.u_afc



