# setup-vps.sh

Meu script básico para configurações iniciais de VPS na DigitalOcean ou similares.

Executa as seguintes etapas de configuração:

* Definição de timezone
* Configurações do usuário root
* Adiciona novo usuário padrão para deploy com privilégio total
* Instala git, zip, unzip, curl, docker e docker-compose
* Adiciona github, gitlab e bitbucket aos hosts confiáveis

Testado em um droplet rodando [Ubuntu Server 18.04 LTS](https://www.ubuntu.com/download/server) com 4GB RAM, mas pode ser utilizado em distribuições similares.

## Uso

```
curl -fsSL https://git.io/fpgbw -o setup-vps.sh && bash setup-vps.sh
```

## Importante
Para que você consiga realizar deploy de aplicações utilizando git e alguma ferramente de implantação como o [deployer](https://deployer.org/), será necessário adicionar a chave pública (id_rsa.pub) do usuário criado no seu servidor VCS (bitbucket, gitlab, github, etc).

## Dicas

Para não ter que digitar a senha todas as vezes que precisar acessar o servidor remoto por SSH ou ter fazer algum deploy, digite o comando a baixo. Isso adicionará sua chave pública no arquivo ```authorized_keys``` do novo usuário criado.

```
ssh-copy-id <USERNAME DO USUARIO CRIADO>@<IP DO SERVIDOR>
```

### Docker boilerplate server

Caso esteja procurando por boilerplate para configuração rápida de containers docker para proxy reverso com nginx, configuração automática de virtualhosts e geração de certificados SSL com Let's Encrypt, veja o repositório [fabioassuncao/docker-boilerplate-nginx-proxy](https://github.com/fabioassuncao/docker-boilerplate-nginx-proxy)

## Contribuição

1. Fork este repositório!
2. Crie sua feature a partir da branch **develop**: `git checkout -b feature/my-new-feature`
3. Escreva e comente seu código.
4. Commit suas alterações: `git commit -am 'Add some feature'`
5. Faça um `push` para a branch: `git push origin feature/my-new-feature`
6. Faça um `pull request` para a branch **develop**

## Créditos

[Fábio Assunção](https://github.com/fabioassuncao) e todos os [contribuidores](https://github.com/setup-vps/graphs/contributors).

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
