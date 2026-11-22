"""Os mesmos olhos para web, Windows e macOS, direto nos lugares do projeto.

Rodar de dentro de `app/`: `python tool/gerar_icones_outros.py`.
O "maskable" da web é como o adaptativo do Android: o navegador recorta até um
círculo de 80% do lado, então os olhos vão menores e o fundo vai até a borda.
"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gerar_icones import legado, frente, fundo  # noqa: E402


def mascaravel(tam):
    quadro = fundo(tam)
    quadro.alpha_composite(frente(tam))
    return quadro


if __name__ == "__main__":
    legado(16).save("web/favicon.png")
    for px in (192, 512):
        legado(px).save(f"web/icons/Icon-{px}.png")
        mascaravel(px).save(f"web/icons/Icon-maskable-{px}.png")

    mac = "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for px in (16, 32, 64, 128, 256, 512, 1024):
        legado(px).save(f"{mac}/app_icon_{px}.png")

    legado(256).save(
        "windows/runner/resources/app_icon.ico",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print("  web, macOS e Windows gerados")
