export interface User {
  id: string;
  name: string;
  phone: string;
  email?: string;
  isAdmin: boolean;
  isActive: boolean;
  createdAt: string;
  storeCount?: number;
}

export interface Store {
  id: string;
  name: string;
  category?: string;
  ownerId: string;
  ownerName?: string;
  planId?: string;
  planName?: string;
  status: 'active' | 'suspended' | 'trial' | 'expired';
  productCount?: number;
  monthlySales?: number;
  lastActivity?: string;
  createdAt: string;
}

export interface Subscription {
  id: string;
  storeId: string;
  storeName: string;
  planId: string;
  planName: string;
  status: 'active' | 'trial' | 'expired' | 'pending' | 'cancelled';
  expiresAt: string;
  discount?: number;
  amount?: number;
  receiptUrl?: string;
  createdAt: string;
}

export interface Plan {
  id: string;
  name: string;
  price: number;
  maxStores: number;
  maxProducts: number;
  maxStaff: number;
  maxDiscounts: number;
  hasReportsAll: boolean;
  hasExport: boolean;
  hasTelegram: boolean;
  hasAllPush: boolean;
  hasDelivery: boolean;
  hasInventory: boolean;
}

export interface Announcement {
  id: string;
  title: string;
  body: string;
  targetPlan?: string;
  targetStatus?: string;
  recipientCount: number;
  sentAt: string;
  sentBy: string;
}

export interface AuditLog {
  id: string;
  date: string;
  userId: string;
  userName: string;
  action: string;
  entity: string;
  entityId?: string;
  details?: string;
  ip?: string;
}

export interface DashboardStats {
  totalUsers: number;
  totalStores: number;
  activeSubscriptions: number;
  trialSubscriptions: number;
  expiredSubscriptions: number;
  monthlyRevenue: number;
  newUsersThisWeek: number;
  newStoresThisWeek: number;
}

export interface RevenuePoint {
  date: string;
  revenue: number;
}

export interface RegistrationPoint {
  date: string;
  users: number;
  stores: number;
}

export interface PendingPayment {
  id: string;
  subscriptionId: string;
  storeId: string;
  storeName: string;
  planName: string;
  amount: number;
  receiptUrl?: string;
  createdAt: string;
}
