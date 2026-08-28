"""Os mesmos olhos, nos tamanhos que o iOS pede.

Sem canto arredondado e **sem transparência**: o iOS arredonda sozinho, e
recusa ícone com canal alfa. Um PNG transparente aqui passa no build e falha
na validação da App Store, tarde demais.
"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gerar import olhos, FUNDO, SS  # noqa: E402


def ios(tam):
    quadro = Image.new("RGB", (tam, tam), FUNDO[:3])
    quadro.paste(olhos(tam, escala=0.92), (0, 0), olhos(tam, escala=0.92))
    return quadro


if __name__ == "__main__":
    destino = sys.argv[1]
    os.makedirs(destino, exist_ok=True)
    # nome -> lado em pixels (base @1x vezes o multiplicador)
    alvos = {
        "Icon-App-20x20@1x": 20, "Icon-App-20x20@2x": 40, "Icon-App-20x20@3x": 60,
        "Icon-App-29x29@1x": 29, "Icon-App-29x29@2x": 58, "Icon-App-29x29@3x": 87,
        "Icon-App-40x40@1x": 40, "Icon-App-40x40@2x": 80, "Icon-App-40x40@3x": 120,
        "Icon-App-60x60@2x": 120, "Icon-App-60x60@3x": 180,
        "Icon-App-76x76@1x": 76, "Icon-App-76x76@2x": 152,
        "Icon-App-83.5x83.5@2x": 167,
        "Icon-App-1024x1024@1x": 1024,
    }
    for nome, px in alvos.items():
        ios(px).save(os.path.join(destino, f"{nome}.png"))
    print(f"  {len(alvos)} ícones de iOS gerados")
