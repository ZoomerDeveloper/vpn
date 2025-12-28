export class CreateServerDto {
  name: string;
  host: string;
  port: number;
  publicIp: string;
  privateIp: string;
  endpoint: string;
  network: string;
  dns?: string;
  publicKey?: string;
  privateKey?: string;
}

