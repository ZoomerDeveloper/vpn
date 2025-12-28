import axios, { AxiosInstance } from 'axios';

export interface User {
  id: string;
  telegramId: string;
  username?: string;
  firstName?: string;
  lastName?: string;
  status: string;
  tariffId?: string;
  expireAt?: string;
  trialUsed: boolean;
  trialExpiresAt?: string;
}

export interface Tariff {
  id: string;
  name: string;
  description?: string;
  price: number;
  currency: string;
  durationDays: number;
  devicesLimit: number;
}

export interface VpnPeer {
  id: string;
  publicKey: string;
  allocatedIp: string;
  isActive: boolean;
  createdAt: string;
}

export interface Payment {
  id: string;
  amount: number;
  currency: string;
  status: string;
  provider: string;
  transactionHash?: string;
}

export class BotService {
  private api: AxiosInstance;

  constructor(baseUrl: string) {
    this.api = axios.create({
      baseURL: baseUrl,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  async getUserByTelegramId(telegramId: string): Promise<User | null> {
    try {
      const response = await this.api.get(`/users/telegram/${telegramId}`);
      return response.data;
    } catch (error: any) {
      if (error.response?.status === 404) {
        return null;
      }
      throw error;
    }
  }

  async createUser(telegramId: string, userData: {
    username?: string;
    firstName?: string;
    lastName?: string;
  }): Promise<User> {
    const response = await this.api.post('/users', {
      telegramId,
      ...userData,
    });
    return response.data;
  }

  async startTrial(userId: string, hours: number = 24): Promise<User> {
    const response = await this.api.post(`/users/${userId}/trial`, { hours });
    return response.data;
  }

  async getTariffs(): Promise<Tariff[]> {
    const response = await this.api.get('/tariffs');
    return response.data;
  }

  async createPayment(userId: string, tariffId: string): Promise<Payment> {
    const response = await this.api.post('/payments', {
      userId,
      tariffId,
      provider: 'usdt_trc20',
    });
    return response.data;
  }

  async getPaymentAddress(paymentId: string): Promise<{ address: string; amount: number }> {
    const response = await this.api.post(`/payments/${paymentId}/address`);
    return response.data;
  }

  async confirmPayment(paymentId: string, transactionHash: string): Promise<Payment> {
    const response = await this.api.post(`/payments/${paymentId}/confirm`, {
      transactionHash,
    });
    return response.data;
  }

  async getUserPeers(userId: string): Promise<VpnPeer[]> {
    const response = await this.api.get(`/vpn/users/${userId}/peers`);
    return response.data;
  }

  async createPeer(userId: string): Promise<{ peer: VpnPeer; config: string }> {
    const response = await this.api.post(`/vpn/users/${userId}/peers`);
    return response.data;
  }

  async getPeerConfig(peerId: string): Promise<string> {
    const response = await this.api.get(`/vpn/peers/${peerId}/config`);
    return response.data.config;
  }

  async deactivatePeer(peerId: string, userId?: string): Promise<void> {
    await this.api.patch(`/vpn/peers/${peerId}/deactivate`, { userId });
  }
}

