# NanoPi R28S OTG Type-C 转 Host 模式与手机网卡支持排错日志

本文档整理了将 NanoPi R28S（RK3528）的 OTG Type-C 接口（`OTG 5V` / `USB-C1`）改造成 **USB Host 模式** 以支持外接设备及手机 USB 网络共享（Android RNDIS/NCM、iPhone IPHEth）的全过程、硬件分析与排错结论。

---

## 一、 背景与硬件可行性分析

1. **硬件接口定义**：
   - NanoPi R28S 设有 `Debug UART`（USB-C2）和 `OTG 5V`（USB-C1）两个 Type-C 接口。
   - `OTG 5V`（USB-C1）出厂默认设计为 **纯整机主电源输入口（Power Sink，5V/3A）** 兼刷机口（Maskrom/Loader模式）。

2. **核心硬件瓶颈**：
   - **供电限制**：接口板载**没有**设计反向 5V 升压或受控电源输出开关。直插普通 USB 设备或手机会导致 R28S 失去主电源直接断电。
   - **必须外接供电**：必须使用**带独立 5V 供电输入的 Type-C OTG Y 型分线器**或**带供电的 USB HUB**，实现“充电头 $\rightarrow$ 分线器 $\rightarrow$ R28S + 外设/手机”的供电链路。
   - **硬件 ID 锁定**：原理图上 `USB20_OTG0_ID` 通过上拉/分压被硬件固定为从机电平（Slave Mode）。

---

## 二、 软件与驱动配置方案

为了突破硬件 ID 限制并原生支持手机热点网卡，在源码层进行了如下自动化集成：

1. **设备树（DTS）强制 Host 模式**：
   - 在编译脚本 `scripts/custome_kernel_config.sh` 中动态为 `kernel/.../rk3528-nanopi-rev03.dts` 的 `&usbdrd_dwc3` 节点注入：
     ```dts
     dr_mode = "host";
     /delete-property/ extcon;
     status = "okay";
     ```
   - 这样系统启动后即强制工作在主机模式（Host Mode），不再依赖硬件 ID 引脚检测。

2. **内核及 OpenWrt 软件包支持**：
   - **Android 手机共享网络**：启用 `kmod-usb-net-rndis`、`kmod-usb-net-cdc-ncm`、`kmod-usb-net-cdc-ether`。
   - **iPhone (iOS) 共享网络**：启用 `kmod-usb-net-ipheth`、`usbmuxd`（USB 多路复用守护进程）、`libimobiledevice`、`libplist` 等配对认证组件。
   - **USB 存储支持**：启用 `kmod-usb-storage`、`kmod-fs-ext4/vfat/exfat`。

---

## 三、 排错历程与核心结论

### 1. 软件层验证：100% 成功
- 通过串口与 SSH 进入 R28S 检查：
  - `/sys/bus/platform/devices/fe500000.dwc3/of_node/dr_mode` 的值为 **`host`**。
  - `/sys/kernel/debug/usb/devices` 显示 `xhci-hcd.0.auto` 根集线器驱动已常驻运行。
  - 确认软件配置完全正确，DWC3 已经成功转为 USB 主机控制器。

### 2. 物理层验证：为什么接扩展坞或手机无反应？
- **现象**：即使扩展坞接了外接供电，外接 U 盘或手机做热点时，系统中断计数仍为 0，终端毫无日志。
- **根本原因**：
  - **智能扩展坞的 CC 握手死锁**：市面上的“电脑 Type-C 扩展坞”内部通常含有 USB Hub 芯片。当它插入 R28S 时，由于 R28S 板载 CC 引脚带有标准的 **5.1kΩ 下拉电阻（Rd）**，扩展坞误认为接入的是另一个受电设备/充电宝，从而**在内部切断了 D+/D- 数据差分信号通路**。
  - **手机作为网卡时的 VBUS 触发依赖**：手机做热点时，必须在线路上检测到真实的 5V VBUS 供电以及完整的数据线连通，才会主动拉高 D+ 触发主机中断。如果数据线被扩展坞内部阻断，或线材没有反向供电给数据触发端，设备就无法被枚举。

---

## 四. 最终排错与解决方案

1. **放弃使用带智能握手芯片的电脑 Type-C 扩展坞**。
2. 改用**纯被动无芯片的 OTG Y 型分线器**（或专用无源供电转接线）：
   - 保证充电头的 5V 电压同时为 R28S 与外设/手机供电。
   - 保证 D+/D- 数据差分线由 R28S 到手机/外设**物理直通**。
3. 只要硬件物理直通建立，D+ 产生 3.3V 拉高电平，RK3528 的 `rockchip_usb2phy_ls` 硬件中断便会瞬间触发，手机和 U 盘即可正常识别并加载对应的 RNDIS/IPHEth 网卡或存储驱动。
