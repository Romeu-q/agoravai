class_name Palette
## Paleta do jogo num lugar só. Qualquer script usa `Palette.GREEN`, etc.
## (Os shaders e os spritesheets usam os mesmos valores.)
##
## - PRINCIPAL (preto, verde, branco): quase tudo.
## - ESPECIAL (rosa, ciano, roxo): efeitos de alto impacto.
## - QUENTE (laranja): RARO de propósito. Significa PERIGO: olhos dos monstros,
##   aviso de spawn, contagem final da wave. Por ser a única cor quente numa
##   tela fria, o olho do jogador vai direto nela.


const BLACK := Color("000000")
const GREEN := Color("39ff14")
const WHITE := Color("ffffff")

const PINK := Color("ff0a8c")
const CYAN := Color("00f0ff")
const PURPLE := Color("b026ff")

const WARM := Color("ff7a2e")
