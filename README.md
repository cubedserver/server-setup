# setup-vps.sh

Meu script básico para configurações iniciais de VPS na DigitalOcean ou similares.

Executa as seguintes etapas de configuração:

* Definição de timezone
* Configurações do usuário root
* Adiciona novo usuário padrão para deploy com privilégio total
* Instala git, zip, unzip, docker, docker-compose
* Adiciona github, gitlab e bitbucket aos hosts confiáveis

Testado no Ubuntu 18.04 com 4GB RAM, mas pode ser utilizado em distribuições similares.

## Uso

Eu sei que essa não é a melhor forma de fazer isso, especialmente se executado como root, mas nada que um pouco de cautela e bom senso não resolva.

```
# bash <(curl -o - https://raw.githubusercontent.com/fabioassuncao/setup-vps/master/setup-vps.sh)
```

## Licença

```
MIT License

Copyright (c) 2018 Fábio Assunção

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
