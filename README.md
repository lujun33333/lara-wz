# lara-wz

面向《王者荣耀》11.4.10103 的 lara 独立分支。项目保留 DarkSword 内核能力，并按 Core 2.2 的功能分组和 900×600 控制界面重写王者只读绘制链。

## 当前范围

- 统一 `wzmem` capability：读取、写入、内核读写、task port、region 枚举。
- 优先使用只读 Mach task transport；获取 task port 失败时回退到原 mapped-pages 通道。
- 通过 `smoba` 进程和 UnityFramework UUID `6a838f46-a5e8-3ec9-bbce-6b01ab2ffad4` 绑定 11.4.10103。
- Core 风格启动页与游戏内面板：初始化、主页、英雄、兵野、其他、调整。
- 游戏启动前通过 SpringBoard RemoteCall 托管绘制、菜单、浮球三个 context；锁屏自动注销、解锁恢复，任一注册或回滚失败都会阻止游戏启动。
- 已接入的只读绘制：真实英雄头像、环形血量、动态回城光环、射线、方框、敌我/视野提示、小地图、地图调节框、分类野怪/计时、兵线。
- 王者采集、投影与英雄头像图集复用并适配自 `own_feature` 的已验证实现。
- 非王者写入链及其入口均已移除；未经当前版本验证的写入/Hook 能力不对外暴露并保持 fail-closed。

## 验证

源码静态门禁：

```powershell
./tests/wz_source_static_test.ps1
```

Mach 部分读取契约的主机测试源码位于 `tests/wzmem_partial_test.c`。当前同步阶段不生成 IPA；构建脚本为 `scripts/build_ipa_wz.sh`。

## 来源与许可

本项目基于 [lara](https://github.com/rooootdev/lara) 的本地分支继续开发，原项目版权及许可见 [LICENSE](LICENSE)。
