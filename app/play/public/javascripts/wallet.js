(() => {
    const ethereum = window.ethereum
    const body = document.body
    const contract = body.dataset.contract
    const expectedChain = Number(body.dataset.chainId || '31337')
    const connect = document.querySelector('#connect-wallet')
    const walletAddress = document.querySelector('#wallet-address')
    let account = null

    const hexUtf8 = text => '0x' + Array.from(new TextEncoder().encode(text), b => b.toString(16).padStart(2, '0')).join('')
    const word = value => BigInt(value).toString(16).padStart(64, '0')
    const addressWord = value => value.toLowerCase().replace(/^0x/, '').padStart(64, '0')
    const bytes32 = value => Array.from(new TextEncoder().encode(value)).slice(0, 32).map(b => b.toString(16).padStart(2, '0')).join('').padEnd(64, '0')

    async function selector(signature) {
        const hash = await ethereum.request({method: 'web3_sha3', params: [hexUtf8(signature)]})
        return hash.slice(2, 10)
    }

    async function requireWallet() {
        if (!ethereum) throw new Error('No injected wallet found')
        const chain = Number(BigInt(await ethereum.request({method: 'eth_chainId'})))
        if (chain !== expectedChain) throw new Error(`Unexpected chain, switch to chain ${expectedChain}`)
        const accounts = await ethereum.request({method: 'eth_requestAccounts'})
        account = accounts[0]
        walletAddress.textContent = account
        connect.textContent = 'Connected'
        return account
    }

    async function send(signature, encodedArgs) {
        const from = await requireWallet()
        const data = '0x' + await selector(signature) + encodedArgs
        const hash = await ethereum.request({method: 'eth_sendTransaction', params: [{from, to: contract, data}]})
        for (; ;) {
            const receipt = await ethereum.request({method: 'eth_getTransactionReceipt', params: [hash]})
            if (receipt) {
                if (receipt.status === '0x0') throw new Error('Transaction reverted')
                break
            }
            await new Promise(resolve => setTimeout(resolve, 500))
        }
        await new Promise(resolve => setTimeout(resolve, 1200))
        location.reload()
    }

    function status(card, message, error = false) {
        const target = card.querySelector('.status')
        target.textContent = message
        target.className = error ? 'status error' : 'status success'
    }

    connect?.addEventListener('click', () => requireWallet().catch(error => alert(error.message)))
    document.querySelectorAll('.pet-card').forEach(card => {
        const id = card.dataset.petId
        card.querySelector('.like')?.addEventListener('click', async () => {
            try {
                const key = 'muttniks-anonymous-session'
                let session = localStorage.getItem(key)
                if (!session) {
                    session = crypto.randomUUID();
                    localStorage.setItem(key, session)
                    localStorage.setItem(`${key}-created`, String(Math.floor(Date.now() / 1000)))
                }
                const created = Number(localStorage.getItem(`${key}-created`) || Math.floor(Date.now() / 1000))
                const response = await fetch(`/pets/${id}/likes`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({session, sessionCreatedAtEpochSecond: created})
                })
                if (!response.ok) throw new Error(`Like failed (${response.status})`)
                location.reload()
            } catch (error) {
                status(card, error.message, true)
            }
        })
        card.querySelector('.adopt')?.addEventListener('click', () => send('adopt(uint256)', word(id)).catch(error => status(card, error.message, true)))
        card.querySelector('.transfer')?.addEventListener('click', () => {
            const to = card.querySelector('.recipient').value
            if (!/^0x[0-9a-fA-F]{40}$/.test(to)) return status(card, 'Enter a valid recipient address', true)
            send('transfer(uint256,address)', word(id) + addressWord(to)).catch(error => status(card, error.message, true))
        })
        card.querySelector('.assign-name')?.addEventListener('click', () => {
            const name = card.querySelector('.pet-name').value
            if (!name || new TextEncoder().encode(name).length > 32) return status(card, 'Name must be 1–32 UTF-8 bytes', true)
            send('assignName(uint256,bytes32)', word(id) + bytes32(name)).catch(error => status(card, error.message, true))
        })
    })
})()
