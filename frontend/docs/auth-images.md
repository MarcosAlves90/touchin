# Fotografias da autenticação

Os painéis de marca das quatro páginas de autenticação utilizam fotografias
publicadas no Cloudinary pelo proprietário do projeto. As URLs utilizadas no
aplicativo são centralizadas em `AuthBrandImages`, em
`lib/features/auth/presentation/widgets/auth_shell.dart`.

| Tela | ID público do Cloudinary | Fotógrafo original |
| --- | --- | --- |
| Login | `login_a7de1w.jpg` | E Vos |
| Cadastro | `cadastro_q0zfus.jpg` | Leon Rohrwild |
| Recuperação de senha | `recuperacao-de-senha_snzc6m.jpg` | Caroline Badran |
| Troca obrigatória de senha | `troca-obrigatoria-de-senha_apzwxa.jpg` | David Kristianto |

Originais publicados sob a [licença Unsplash](https://unsplash.com/license):

- https://unsplash.com/photos/modern-office-interior-with-glass-walls-and-walkways-V_yQ8IyCmYY
- https://unsplash.com/photos/a-modern-skyscrapers-glass-facade-and-office-interior-SVNqxZlv9CM
- https://unsplash.com/photos/modern-office-interior-with-glass-walls-and-plants-B74lBYC3PXI
- https://unsplash.com/photos/modern-conference-room-with-chairs-and-table-6jpbs2ykacU

As transformações `f_auto,q_auto:best,w_1920,c_limit` permitem negociar o
formato compatível com o navegador, preservar mais detalhes e limitar a largura
de transferência a 1920 pixels sem ampliar originais menores. Não há arquivos
fotográficos no bundle Flutter. O painel com imagem é construído apenas quando
a largura disponível é de pelo menos 920 pixels. Se a imagem remota não carregar,
o fundo escuro do painel permanece visível, preservando o contraste do conteúdo.
