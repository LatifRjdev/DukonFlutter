'use client';

import { use, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Package, Users, TrendingUp, Clock, Ban, UserCheck, Send } from 'lucide-react';
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
import { Textarea } from '@/components/ui/textarea';
import { StatsCard } from '@/components/stats-card';
import { api } from '@/lib/api';
import { Store, Subscription } from '@/lib/types';
import { toast } from 'sonner';
import { format } from 'date-fns';

const SUB_STATUS_LABELS: Record<string, string> = {
  ACTIVE: 'Активна',
  TRIAL: 'Trial',
  PAST_DUE: 'Просрочена',
  CANCELED: 'Отменена',
  EXPIRED: 'Истекла',
};

const SUB_STATUS_COLORS: Record<string, string> = {
  ACTIVE: 'bg-green-100 text-green-700',
  TRIAL: 'bg-blue-100 text-blue-700',
  PAST_DUE: 'bg-yellow-100 text-yellow-700',
  CANCELED: 'bg-gray-100 text-gray-600',
  EXPIRED: 'bg-red-100 text-red-700',
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
  const [messageDialog, setMessageDialog] = useState(false);
  const [msgTitle, setMsgTitle] = useState('');
  const [msgBody, setMsgBody] = useState('');

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
      api.put(`/admin/stores/${id}/${store && !store.isActive ? 'unsuspend' : 'suspend'}`),
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

  const sendMessageMutation = useMutation({
    mutationFn: () =>
      api.post('/admin/notifications/direct', { storeId: id, title: msgTitle, body: msgBody }),
    onSuccess: () => {
      setMessageDialog(false);
      setMsgTitle('');
      setMsgBody('');
      toast.success('Сообщение отправлено');
    },
    onError: () => toast.error('Ошибка отправки сообщения'),
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
                Владелец: <span className="font-medium text-foreground">{store.owner?.name || '—'}</span>
              </p>
              <p className="text-sm text-muted-foreground">
                Создан:{' '}
                {store.createdAt ? format(new Date(store.createdAt), 'dd.MM.yyyy') : '—'}
              </p>
            </div>
            {!store.isActive ? (
              <Badge className="bg-red-100 text-red-700 hover:opacity-80">
                Приостановлен
              </Badge>
            ) : store.subscription ? (
              <Badge className={`${SUB_STATUS_COLORS[store.subscription.status] || ''} hover:opacity-80`}>
                {SUB_STATUS_LABELS[store.subscription.status] || store.subscription.status}
              </Badge>
            ) : (
              <Badge variant="outline">—</Badge>
            )}
          </div>

          <Separator />

          <div className="flex gap-3">
            <Button
              variant={!store.isActive ? 'outline' : 'destructive'}
              onClick={() => suspendMutation.mutate()}
              disabled={suspendMutation.isPending}
            >
              {!store.isActive ? (
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
            <Button variant="outline" onClick={() => setMessageDialog(true)}>
              <Send className="mr-2 h-4 w-4" />
              Отправить сообщение
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-4">
        <StatsCard
          title="Товары"
          value={store._count?.products ?? 0}
          icon={Package}
        />
        <StatsCard
          title="Продаж/месяц"
          value={store.monthlySalesCount ?? 0}
          icon={TrendingUp}
        />
        <StatsCard
          title="Последняя продажа"
          value={store.lastSaleDate ? format(new Date(store.lastSaleDate), 'dd.MM') : '—'}
          icon={Clock}
        />
        <StatsCard
          title="Тариф"
          value={store.subscription?.plan || '—'}
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
                <p className="font-medium">{subscription.plan}</p>
              </div>
              <div>
                <p className="text-muted-foreground">Статус</p>
                <Badge className={`${SUB_STATUS_COLORS[subscription.status] || ''} hover:opacity-80`}>
                  {SUB_STATUS_LABELS[subscription.status] || subscription.status}
                </Badge>
              </div>
              <div>
                <p className="text-muted-foreground">Истекает</p>
                <p className="font-medium">
                  {subscription.currentPeriodEnd
                    ? format(new Date(subscription.currentPeriodEnd), 'dd.MM.yyyy')
                    : '—'}
                </p>
              </div>
              {subscription.adminDiscount !== undefined &&
                subscription.adminDiscount !== null &&
                subscription.adminDiscount > 0 && (
                  <div>
                    <p className="text-muted-foreground">Скидка</p>
                    <p className="font-medium">{subscription.adminDiscount}%</p>
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

      {/* Send Message Dialog */}
      <Dialog open={messageDialog} onOpenChange={setMessageDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Отправить сообщение магазину</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label>Заголовок</Label>
              <Input value={msgTitle} onChange={(e) => setMsgTitle(e.target.value)} maxLength={200} />
            </div>
            <div className="space-y-2">
              <Label>Текст</Label>
              <Textarea value={msgBody} onChange={(e) => setMsgBody(e.target.value)} rows={4} maxLength={1000} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setMessageDialog(false)}>
              Отмена
            </Button>
            <Button
              onClick={() => sendMessageMutation.mutate()}
              disabled={!msgTitle.trim() || !msgBody.trim() || sendMessageMutation.isPending}
            >
              <Send className="mr-2 h-4 w-4" />
              Отправить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
