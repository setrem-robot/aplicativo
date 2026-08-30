"""Gera o ícone do Atlas Controller: os olhos da Atlas.

A forma não é inventada — é a do rosto que roda no robô: uma caixa arredondada
(ver `corner_radius = 0.30` em `config.py` no RobotEye). Quem já viu a Atlas
ligada reconhece o ícone sem ler o nome.

Os dois olhos são idênticos. O rosto que roda no robô baixa o olho direito ~7%,
e o ícone imitava isso — mas num ícone de 48 px a diferença não lê como a
assimetria viva do rosto, lê como desalinhamento. Lá o robô pisca e se mexe, e a
assimetria some no movimento; aqui a forma fica parada.

Duas decisões que vieram de olhar o resultado, e não da teoria:

- **Os olhos ocupam ~70% da largura.** A primeira versão usava 60% e, no
  tamanho mdpi (48 px) — que é justamente onde o ícone mais é visto —, viravam
  dois pontinhos num quadrado escuro.
- **O raio é 1/3 da largura do olho, não metade.** Com metade, a forma vira
  cápsula e perde a cara de caixa arredondada que a Atlas tem.
"""
from PIL import Image, ImageDraw

FUNDO = (10, 14, 26, 255)      # AppColors.background #0A0E1A
MENTA = (36, 255, 194)         # AppColors.secondary  #24FFC2
VERDE = (9, 208, 133)          # AppColors.primary    #09D085
SS = 4                          # supersampling: a borda em 48 px serrilharia


def _degrade(T, x0, y0, x1, y1):
    """Menta -> verde na diagonal, como o AppColors.brandGradient.

    Pintado só sobre a área dos olhos: um degradê espalhado pelo quadro inteiro
    ficaria quase de uma cor só na parte que aparece.
    """
    grad = Image.new("RGB", (T, T), VERDE)
    px = grad.load()
    span = max((x1 - x0) + (y1 - y0), 1)
    for y in range(T):
        for x in range(T):
            t = min(max(((x - x0) + (y - y0)) / span, 0.0), 1.0)
            px[x, y] = tuple(int(MENTA[c] + (VERDE[c] - MENTA[c]) * t) for c in range(3))
    return grad


def olhos(tam, escala=1.0):
    """Os dois olhos num quadro transparente. `escala` encolhe o par."""
    T = tam * SS
    larg = 0.305 * T * escala
    alt = 0.450 * T * escala
    vao = 0.080 * T * escala
    raio = larg * 0.34             # caixa arredondada, não cápsula

    total = larg * 2 + vao
    x0 = (T - total) / 2
    cy = T / 2
    topo = cy - alt / 2

    mascara = Image.new("L", (T, T), 0)
    md = ImageDraw.Draw(mascara)
    for i in range(2):
        ex = x0 + i * (larg + vao)
        md.rounded_rectangle(
            [ex, topo, ex + larg, topo + alt], radius=raio, fill=255
        )

    quadro = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    quadro.paste(_degrade(T, x0, topo, x0 + total, topo + alt), (0, 0), mascara)
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
