@echo off
cd\
cls

:: Desconecta unidades de rede antigas
net use o: /delete /y
net use k: /delete /y
net use w: /delete /y
net use z: /delete /y
net use j: /delete /y

:: Conecta às novas unidades de rede
net use o: \\CDTNT\Compra /y
net use k: \\CDTNT\Apl /y
net use w: \\CDTNT\Sysd /y
net use z: \\CDTNT\Compartilhado /y
net use j: \\CDTNT\Public /y
