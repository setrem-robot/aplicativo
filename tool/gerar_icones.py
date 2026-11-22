"""Gera o ícone do Atlas Controller: o rosto da Atlas, como ele aparece no robô.

Nada aqui é inventado. Cada medida sai do rosto que roda no Pi (RobotEye):

- **Olhos quadrados**, 640 x 640 no referencial 2560 x 1440 (`face/layout.py`),
  com canto de raio 0,30 do lado (`EYE_CORNER_RADIUS` em `config.py`).
- **Centros em 1/3 e 2/3 da largura da tela** (`leftEyeX`/`rightEyeX`), ou
  seja, 853 unidades entre um e outro.
- **A boca neutra**: um traço de 0,52 x 820 de comprimento, meia-espessura
  0,11 x 120, centrado 470 unidades abaixo dos olhos, a 50% de opacidade
  (`MOUTH_NEUTRAL` em `face/shapes.py`, `MOUTH_*` em `face/layout.py`).
- **Cor chapada `#04C9FD` sobre preto**, sem degradê nem halo: no Pi
  (aarch64) a qualidade `auto` cai para `LOW`, que desenha assim
  (`qualityFor` em `face/renderer.py`). É o rosto que quem vê o robô conhece.

O ícone mostra o rosto inteiro enquadrado, só reescalado. Se o rosto mudar no
RobotEye, é aqui que as constantes abaixo precisam acompanhar.
"""
from PIL import Image, ImageDraw

FUNDO = (0, 0, 0, 255)          # BACKGROUND_COLOR padrão do rosto, #000000
OLHO = (4, 201, 253)            # EYE_COLOR, #04C9FD
SS = 4                          # supersampling: a borda em 48 px serrilharia

# Rosto em unidades do referencial do RobotEye, origem no meio dos dois olhos.
LADO = 640                      # EYE_WIDTH = EYE_HEIGHT
RAIO = 0.30 * LADO              # EYE_CORNER_RADIUS
CENTRO_X = 2560 / 6             # olhos em W/3 e 2W/3: ±W/6 do meio
BOCA_Y = 320 + 150              # MOUTH_Y_OFFSET - EYE_Y_OFFSET
BOCA_MEIO = 0.52 * 820 / 2      # MOUTH_NEUTRAL.width x MOUTH_WIDTH, metade
BOCA_ESP = 0.11 * 240 / 2       # MOUTH_NEUTRAL.thickness x meia MOUTH_HEIGHT
BOCA_ALFA = 0.5                 # MOUTH_NEUTRAL.alpha

# Caixa do rosto inteiro (dos cantos dos olhos ao pé da boca).
_ESQ, _DIR = -CENTRO_X - LADO / 2, CENTRO_X + LADO / 2
_TOPO, _BASE = -LADO / 2, BOCA_Y + BOCA_ESP
LARGURA_ROSTO = _DIR - _ESQ
OCUPA = 0.72                    # fração da largura do ícone que o rosto ocupa


def olhos(tam, escala=1.0):
    """O rosto (olhos e boca) num quadro transparente. `escala` encolhe tudo."""
    T = tam * SS
    k = OCUPA * escala * T / LARGURA_ROSTO       # unidades do robô -> pixels
    ox = T / 2 - (_ESQ + _DIR) / 2 * k           # centraliza a caixa do rosto
    oy = T / 2 - (_TOPO + _BASE) / 2 * k

    quadro = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(quadro)
    for cx in (-CENTRO_X, CENTRO_X):
        d.rounded_rectangle(
            [ox + (cx - LADO / 2) * k, oy - LADO / 2 * k,
             ox + (cx + LADO / 2) * k, oy + LADO / 2 * k],
            radius=RAIO * k, fill=OLHO + (255,),
        )

    # A boca é uma cápsula: retângulo com as pontas redondas.
    boca = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    e = BOCA_ESP * k
    ImageDraw.Draw(boca).rounded_rectangle(
        [ox - (BOCA_MEIO + BOCA_ESP) * k, oy + BOCA_Y * k - e,
         ox + (BOCA_MEIO + BOCA_ESP) * k, oy + BOCA_Y * k + e],
        radius=e, fill=OLHO + (int(255 * BOCA_ALFA),),
    )
    quadro.alpha_composite(boca)
    return quadro.resize((tam, tam), Image.LANCZOS)


def legado(tam):
    """Ícone quadrado tradicional: fundo arredondado + olhos."""
    T = tam * SS
    mask = Image.new("L", (T, T), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, T - 1, T - 1], radius=int(T * 0.22), fill=255)
    base = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    base.paste(Image.new("RGBA", (T, T), FUNDO), (0, 0), mask)
    base = base.resize((tam, tam), Image.LANCZOS)
    base.alpha_composite(olhos(tam, escala=0.92))
    return base


def frente(tam):
    """Camada da frente do adaptativo: só os 2/3 centrais são garantidos."""
    return olhos(tam, escala=0.62)


def fundo(tam):
    return Image.new("RGBA", (tam, tam), FUNDO)


if __name__ == "__main__":
    import os, sys
    saida = sys.argv[1]
    os.makedirs(saida, exist_ok=True)

    for nome, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                     "xxhdpi": 144, "xxxhdpi": 192}.items():
        d = os.path.join(saida, f"mipmap-{nome}")
        os.makedirs(d, exist_ok=True)
        legado(px).save(os.path.join(d, "ic_launcher.png"))
        pa = int(px * 2.25)        # 108dp de moldura para 48dp de conteúdo
        frente(pa).save(os.path.join(d, "ic_launcher_foreground.png"))
        fundo(pa).save(os.path.join(d, "ic_launcher_background.png"))
        print(f"  {nome}: {px}px legado, {pa}px adaptativo")

    # --- folha de conferência ---------------------------------------------
    # Os tamanhos reais lado a lado, e o adaptativo nas duas máscaras que os
    # lançadores mais usam. Ver antes de instalar é o que pega "some no 48".
    L, A = 820, 360
    folha = Image.new("RGBA", (L, A), (24, 28, 40, 255))
    d = ImageDraw.Draw(folha)

    d.text((34, 18), "ic_launcher (legado), nos tamanhos reais", fill=(150, 160, 180))
    x = 34
    for px in (192, 144, 96, 72, 48):
        folha.alpha_composite(legado(px), (x, 56))
        d.text((x, 40), f"{px}px", fill=(110, 120, 140))
        x += px + 24

    def recorte(px, forma):
        """Simula o que o lançador mostra: os 2/3 centrais, ampliados e mascarados.

        Recortar o quadro inteiro daria uma prévia enganosa — os olhos
        pareceriam menores do que ficam de verdade, e levaria a aumentá-los
        sem necessidade.
        """
        moldura = int(px * 2.25)
        camada = Image.new("RGBA", (moldura, moldura), (0, 0, 0, 0))
        camada.alpha_composite(fundo(moldura))
        camada.alpha_composite(frente(moldura))
        margem = int(moldura * (1 - 2 / 3) / 2)
        visivel = camada.crop(
            (margem, margem, moldura - margem, moldura - margem)
        ).resize((px, px), Image.LANCZOS)

        m = Image.new("L", (px, px), 0)
        md = ImageDraw.Draw(m)
        if forma == "circulo":
            md.ellipse([0, 0, px - 1, px - 1], fill=255)
        else:
            md.rounded_rectangle([0, 0, px - 1, px - 1], radius=int(px * 0.30), fill=255)
        fora = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        fora.paste(visivel, (0, 0), m)
        return fora

    d.text((34, 268), "adaptativo, como o lançador recorta:", fill=(150, 160, 180))
    x = 34
    for forma in ("circulo", "squircle"):
        folha.alpha_composite(recorte(64, forma), (x, 288))
        x += 84
    folha.save(os.path.join(saida, "conferencia.png"))
    print("  conferência: conferencia.png")

    # --- o ícone em tamanho de cartaz --------------------------------------
    # Nada aqui usa: é para slide, capa de repositório e impressão. Duas
    # versões porque as duas fazem falta — sobre fundo claro o quadro escuro
    # do ícone é o que se quer, e sobre o fundo escuro do slide só os olhos.
    legado(1024).save(os.path.join(saida, "atlas-icone-1024.png"))
    olhos(1024).save(os.path.join(saida, "atlas-olhos-1024.png"))
    print("  cartaz: atlas-icone-1024.png, atlas-olhos-1024.png")
