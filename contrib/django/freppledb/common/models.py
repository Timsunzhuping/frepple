#
# Copyright (C) 2007 by Johan De Taeye
#
# This library is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation; either version 2.1 of the License, or
# (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
# General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA
#

# file : $URL$
# revision : $LastChangedRevision$  $LastChangedBy$
# date : $LastChangedDate$

from datetime import timedelta

from django.db import models
from django.contrib.auth.models import User
from django.dispatch import dispatcher
from django.db.models import signals
from django.utils.translation import ugettext_lazy as _

from input.models import Plan


class Preferences(models.Model):
  buckettype = (
    ('standard',_('Standard')),
    ('day',_('Day')),
    ('week',_('Week')),
    ('month',_('Month')),
    ('quarter',_('Quarter')),
    ('year',_('Year')),
  )
  csvOutputType = (
    ('table',_('Table')),
    ('list',_('List')),
  )
  user = models.ForeignKey(User, verbose_name=_('user'), unique=True)
  buckets = models.CharField(_('buckets'), max_length=10, choices=buckettype,
    default='standard')
  startdate = models.DateField(_('startdate'), blank=True, null=True)
  enddate = models.DateField(_('enddate'), blank=True, null=True)
  lastmodified = models.DateTimeField(_('last modified'), auto_now=True, editable=False, db_index=True)


def CreatePreferenceModel(instance, **kwargs):
  '''Create a preference model for a new user.'''
  pref, created = Preferences.objects.get_or_create(user=instance)
  if created:
    try:
      pref.startdate = Plan.objects.all()[0].currentdate.date()
      pref.enddate = pref.startdate + timedelta(365)
    except: pass  # No real problem when this fails
    pref.save()

# This signal will make sure a preference model is created when a user is added.
# The preference model is automatically deleted again when the user is deleted.
signals.post_save.connect(CreatePreferenceModel, sender=User)
