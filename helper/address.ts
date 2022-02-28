/**
 * Full list of contract addresses see:
 * 
 * https://paycer.gitbook.io/paycer/paycer-token/smart-contracts
 */

interface AddressType {
    [network: string]: string
}

export const TokenAddress: AddressType = {
    matic: '0xa6083abe845fbB8649d98B8586cBF50b7f233612',
    mumbai: '0xD8eA7F7D3eebB5193AE76E3280b8650FD1468663',
}
  
export const RewardTreasuryAddress: AddressType = {
    matic: '0xD63A987AA4CdA0b71BbFeD8aE1E7EB4329E65016',
    mumbai: '0xD63A987AA4CdA0b71BbFeD8aE1E7EB4329E65016',
}
  
export const FeeCollectorAddress: AddressType = {
    matic: '0x19798bd23393f02312C2D99f807B22C8B6CAe733',
    mumbai: '0x19798bd23393f02312C2D99f807B22C8B6CAe733',
}

export const StakingAddress: AddressType = {
    matic: '0x9F73a9D1777DAb73eb41A29782858f86aA4624B6',
    mumbai: '0x5C86297b9759B1994Ab2fAeeE411817c50190Ac5',
}

export default {
    TokenAddress,
    RewardTreasuryAddress,
    FeeCollectorAddress
}
  