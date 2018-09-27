# 在 vim 中写 perl 脚本的实用插件

## 目前提供的功能

### Perldoc 读文档

* 命令 `:Perldoc {arg}` 查阅文档。
* 用快捷键 `K` 将光标下单词传给 `:Perldoc` 查阅文档

### PerlOmni 补全

提供了一个补全函数，可在 `ftplugin/perl.vim` 中加入类似如下配置启用：

```vim
setlocal omnifunc=PerlComplete
```

补全规则可基于正则表达式灵活扩展。如果 vim 有 `+perl` 编译功能，补全效果更佳。

也已适配 neocomplete 或 deoplete 自动补全插件的补全源。

## 安装

按常规 vim 插件安装即可。

若想手动安装的，将 `autoload/useperl` 子目录下载复制到任一 `rtp` 路径，
然后使用如下命令激活该插件：

```vim
: call useperl#plugin#load()
```

## 致谢

* https://github.com/hotchpotch/perldoc-vim
* https://github.com/c9s/perlomni.vim

本插件重组改写了以上两个（老）插件。

* https://github.com/vim-perl/vim-perl

日常写 perl 脚本也推荐上面这个插件，提供基础语法文件等，vim 官方发布包的 perl
支持也基于此。但该插件应该更新。

* https://github.com/WolfgangMehner/perl-support

perl-support 是另一个颇为繁重的插件，功能很多，但我暂未采用。因此习惯了 
[SirVer/ultisnips](https://github.com/SirVer/ultisnips) 插件，就不想多看它提供的 template 功能了。
