'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import {
  Users,
  Store,
  CreditCard,
  Clock,
  XCircle,
  TrendingUp,
  UserPlus,
  Building2,
} from 'lucide-react';
import { StatsCard } from '@/components/stats-card';
import { RevenueChart } from '@/components/charts/revenue-chart';
import { RegistrationsChart } from '@/components/charts/registrations-chart';
import { Badge } from '@/components/ui/badge';
import { buttonVariants } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { api } from '@/lib/api';
import {
  DashboardStats,
  RevenuePoint,
  RegistrationPoint,
  PendingPayment,
} from '@/lib/types';

function generateMockRevenue(): RevenuePoint[] {
  const data: RevenuePoint[] = [];
  const now = new Date();
  for (let i = 29; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    data.push({
      date: d.toISOString().slice(0, 10),
      revenue: Math.floor(Math.random() * 5000 + 2000),
    });
  }
  return data;
}

function generateMockRegistrations(): RegistrationPoint[] {
  const data: RegistrationPoint[] = [];
  const now = new Date();
  for (let i = 29; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    data.push({
      date: d.toISOString().slice(0, 10),
      users: Math.floor(Math.random() * 20 + 5),
      stores: Math.floor(Math.random() * 10 + 2),
    });
  }
  return data;
}

export default function DashboardPage() {
  const { data: stats, isLoading: statsLoading } = useQuery<DashboardStats>({
    queryKey: ['dashboard-stats'],
    queryFn: () => api.get('/admin/dashboard'),
  });

  const { data: revenueData } = useQuery<RevenuePoint[]>({
    queryKey: ['revenue-chart'],
    queryFn: () => api.get('/admin/revenue'),
  });

  const { data: registrationData } = useQuery<RegistrationPoint[]>({
    queryKey: ['registrations-chart'],
    queryFn: () => api.get('/admin/dashboard/registrations'),
  });

  const { data: pendingPayments } = useQuery<PendingPayment[]>({
    queryKey: ['pending-payments'],
    queryFn: () => api.get('/admin/subscriptions/pending-payments'),
  });

  const mockRevenue = generateMockRevenue();
  const mockRegistrations = generateMockRegistrations();

  const cardData = [
    {
      title: 'Пользователи',
      value: stats?.totalUsers ?? 0,
      icon: Users,
      description: 'Всего зарегистрировано',
      href: '/users',
    },
    {
      title: 'Магазины',
      value: stats?.totalStores ?? 0,
      icon: Store,
      description: 'Всего магазинов',
      href: '/stores',
    },
    {
      title: 'Активные подписки',
      value: stats?.activeSubscriptions ?? 0,
      icon: CreditCard,
      description: 'Оплаченные подписки',
      href: '/subscriptions?status=ACTIVE',
    },
    {
      title: 'Trial',
      value: stats?.trialSubscriptions ?? 0,
      icon: Clock,
      description: 'Пробный период',
      href: '/subscriptions?status=TRIAL',
    },
    {
      title: 'Истекшие',
      value: stats?.expiredSubscriptions ?? 0,
      icon: XCircle,
      description: 'Подписки истекли',
      href: '/subscriptions?status=EXPIRED',
    },
    {
      title: 'Выручка за месяц',
      value: stats
        ? new Intl.NumberFormat('ru-TJ', {
            style: 'currency',
            currency: 'TJS',
            maximumFractionDigits: 0,
          }).format(stats.monthlyRevenue)
        : '—',
      icon: TrendingUp,
      description: 'Текущий месяц',
      href: '/subscriptions',
    },
    {
      title: 'Новые за неделю',
      value: stats?.newUsersThisWeek ?? 0,
      icon: UserPlus,
      description: 'Новые пользователи',
      href: '/users',
    },
    {
      title: 'Новые магазины',
      value: stats?.newStoresThisWeek ?? 0,
      icon: Building2,
      description: 'За последнюю неделю',
      href: '/stores',
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Дашборд</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Обзор ключевых показателей
        </p>
      </div>

      {/* Stats grid */}
      <div className="grid grid-cols-4 gap-4">
        {cardData.map((card) => (
          <StatsCard
            key={card.title}
            title={card.title}
            value={statsLoading ? '...' : card.value}
            description={card.description}
            icon={card.icon}
            href={card.href}
          />
        ))}
      </div>

      {/* Charts */}
      <div className="grid grid-cols-2 gap-6">
        <RevenueChart data={revenueData ?? mockRevenue} />
        <RegistrationsChart data={registrationData ?? mockRegistrations} />
      </div>

      {/* Pending Payments */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-base">Ожидают оплаты</CardTitle>
          <Link
            href="/subscriptions?tab=pending"
            className={buttonVariants({ variant: 'outline', size: 'sm' })}
          >
            Все заявки
          </Link>
        </CardHeader>
        <CardContent>
          {!pendingPayments || pendingPayments.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-4">
              Нет ожидающих платежей
            </p>
          ) : (
            <div className="space-y-3">
              {pendingPayments.slice(0, 5).map((p) => (
                <div
                  key={p.id}
                  className="flex items-center justify-between rounded-lg border p-3"
                >
                  <div>
                    <p className="font-medium text-sm">{p.subscription?.store?.name || '—'}</p>
                    <p className="text-xs text-muted-foreground">{p.subscription?.plan || '—'}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="font-semibold text-sm">
                      {new Intl.NumberFormat('ru-TJ', {
                        style: 'currency',
                        currency: 'TJS',
                        maximumFractionDigits: 0,
                      }).format(p.amount)}
                    </span>
                    <Badge variant="outline" className="text-yellow-700 border-yellow-300 bg-yellow-50">
                      Ожидает
                    </Badge>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
