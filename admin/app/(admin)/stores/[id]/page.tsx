'use client';

import { use, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Package, Users, TrendingUp, Clock, Ban, UserCheck } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Input } from '@/components/ui/input';
import { StatsCard } from '@/components/stats-card';
import { api } from '@/lib/api';
import { Store, Subscription } from '@/lib/types';
import { toast } from 'sonner';
import { format } from 'date-fns';

const STATUS_LABELS: Record<string, string> = {
  active: 'Активен',
  trial: 'Trial',
  suspended: 'Приостановлен',
  expired: 'Истёк',
};

const STATUS_COLORS: Record<string, string> = {
  active: 'bg-green-100 text-green-700',
  trial: 'bg-blue-100 text-blue-700',
  suspended: 'bg-red-100 text-red-700',
  expired: 'bg-yellow-100 text-yellow-700',
};

export default function StoreDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const router = useRouter();
  const queryClient = useQueryClient();
  const [transferDialog, setTransferDialog] = useState(false);
  const [newOwnerId, setNewOwnerId] = useState('');

  const { data: store, isLoading } = useQuery<Store>({
    queryKey: ['store', id],
    queryFn: () => api.get(`/admin/stores/${id}`),
  });

  const { data: subscription } = useQuery<Subscription>({
    queryKey: ['store-subscription', id],
    queryFn: () => api.get(`/admin/stores/${id}/subscription`),
  });

  const suspendMutation = useMutation({
    mutationFn: () =>
      api.put(`/admin/stores/${id}/${store?.status === 'suspended' ? 'unsuspend' : 'suspend'}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['store', id] });
      toast.success('Статус магазина обновлён');
    },
    onError: () => toast.error('Ошибка обновления статуса'),
  });

  const transferMutation = useMutation({
    mutationFn: (userId: string) =>
      api.put(`/admin/stores/${id}/transfer`, { userId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['store', id] });
      setTransferDialog(false);
      setNewOwnerId('');
      toast.success('Владелец магазина изменён');
    },
    onError: () => toast.error('Ошибка передачи магазина'),
  });

  if (isLoading) {
    return (
      <div className="space-y-4">
        <div className="h-8 w-48 animate-pulse rounded bg-slate-100" />
        <div className="h-48 animate-pulse rounded bg-slate-100" />
      </div>
    );
  }

  if (!store) {
    return (
      <div className="text-center py-12">
        <p className="text-muted-foreground">Магазин не найден</p>
        <Button variant="outline" onClick={() => router.back()} className="mt-4">
          Назад
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-4xl">
      <Button variant="ghost" onClick={() => router.back()} className="-ml-2">
        <ArrowLeft className="mr-2 h-4 w-4" />
        Назад
      </Button>

      {/* Store Info */}
      <Card>
        <CardHeader>
          <CardTitle>Информация о магазине</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-start justify-between">
            <div>
              <h2 className="text-xl font-semibold">{store.name}</h2>
              {store.category && (
                <p className="text-muted-foreground text-sm">{store.category}</p>
              )}
              <p className="text-sm text-muted-foreground mt-1">
                Владелец: <span className="font-medium text-foreground">{store.ownerName || '—'}</span>
              </p>
              <p className="text-sm text-muted-foreground">
                Создан:{' '}
                {store.createdAt ? format(new Date(store.createdAt), 'dd.MM.yyyy') : '—'}
              </p>
            </div>
            <Badge className={`${STATUS_COLORS[store.status] || ''} hover:opacity-80`}>
              {STATUS_LABELS[store.status] || store.status}
            </Badge>
          </div>

          <Separator />

          <div className="flex gap-3">
            <Button
              variant={store.status === 'suspended' ? 'outline' : 'destructive'}
              onClick={() => suspendMutation.mutate()}
              disabled={suspendMutation.isPending}
            >
              {store.status === 'suspended' ? (
                <>
                  <UserCheck className="mr-2 h-4 w-4" />
                  Восстановить
                </>
              ) : (
                <>
                  <Ban className="mr-2 h-4 w-4" />
                  Приостановить
                </>
              )}
            </Button>
            <Button variant="outline" onClick={() => setTransferDialog(true)}>
              Передать владение
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-4">
        <StatsCard
          title="Товары"
          value={store.productCount ?? 0}
          icon={Package}
        />
        <StatsCard
          title="Продаж/месяц"
          value={store.monthlySales ?? 0}
          icon={TrendingUp}
        />
        <StatsCard
          title="Последняя активность"
          value={store.lastActivity ? format(new Date(store.lastActivity), 'dd.MM') : '—'}
          icon={Clock}
        />
        <StatsCard
          title="Тариф"
          value={store.planName || '—'}
          icon={Users}
        />
      </div>

      {/* Subscription */}
      {subscription && (
        <Card>
          <CardHeader>
            <CardTitle>Подписка</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <p className="text-muted-foreground">Тариф</p>
                <p className="font-medium">{subscription.planName}</p>
              </div>
              <div>
                <p className="text-muted-foreground">Статус</p>
                <Badge className={`${STATUS_COLORS[subscription.status] || ''} hover:opacity-80`}>
                  {subscription.status}
                </Badge>
              </div>
              <div>
                <p className="text-muted-foreground">Истекает</p>
                <p className="font-medium">
                  {subscription.expiresAt
                    ? format(new Date(subscription.expiresAt), 'dd.MM.yyyy')
                    : '—'}
                </p>
              </div>
              {subscription.discount !== undefined && subscription.discount > 0 && (
                <div>
                  <p className="text-muted-foreground">Скидка</p>
                  <p className="font-medium">{subscription.discount}%</p>
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Transfer Dialog */}
      <Dialog open={transferDialog} onOpenChange={setTransferDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Передать магазин</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">
              Магазин: <strong>{store.name}</strong>
            </p>
            <div className="space-y-2">
              <Label>ID нового владельца</Label>
              <Input
                value={newOwnerId}
                onChange={(e) => setNewOwnerId(e.target.value)}
                placeholder="Введите ID пользователя"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setTransferDialog(false)}>
              Отмена
            </Button>
            <Button
              onClick={() => transferMutation.mutate(newOwnerId)}
              disabled={!newOwnerId || transferMutation.isPending}
            >
              Передать
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
