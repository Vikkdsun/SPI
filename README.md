# SPI
spi drive FLASH project by verilog

Create Date: 2023/9/15 22:45

### SPI驱动FLASH
通过TYPE控制写指令、读数据、写数据

通过op_len来控制有没有req，能不能读出数据

### 本项目写了TB，FLASH内容还没补充
drive文件有注释，是写代码的心路历程，容易理解

### 更新log
2023/9/18  0:27  :更新FLASH_CTRL模块

2023/9/18 9:18  :更新SPI_DRIVE和FLASH_CTRL，修复BUG

2023/9/18 9:49  :更新FLASH_DRIVE模块，封装SPI_DRIVE和FLASH_CTRL模块

2023/9/18 10:12  :更新FLASH_DRIVE模块，修复输入输出端口方向定义，修复BUG

2023/9/18 15:21  :更新user_gen_data模块，更新FLASH_DRIVE_TB，还未仿真测试

等待更新...
