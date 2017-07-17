# coding=utf-8
import logging
import re

import scrapy

from scrapy.linkextractors import LinkExtractor
from scrapy.spiders import CrawlSpider, Rule
from scrapy.pipelines.files import FilesPipeline
from w3lib.html import remove_tags, replace_tags
import slugify

import coloredlogs

coloredlogs.install(level='DEBUG')

DEFAULT_LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'loggers': {
        'scrapy': {
            'level': 'DEBUG',
        },
    }
}

logging.config.dictConfig(DEFAULT_LOGGING)


class MyFilesPipeline(FilesPipeline):
    def file_path(self, request, response=None, info=None):
        return request.meta.get('filename','')

    def get_media_requests(self, item, info):
        url = item['file'][0]
        meta = {'filename':  slugify.slugify_unicode(item['title']) + '.pdf'}
        yield scrapy.Request(url=url, meta=meta)

# %%
class Spider(CrawlSpider):
    name = "hse.ru"

    # allowed_domains = ['www.site.com']

    rules = (
        Rule(LinkExtractor(allow=(r'links/.*$'), deny=('')), callback='parse_item'),
        Rule(LinkExtractor(allow=(r'links/[a-z]/\d+'))),
    )
    custom_settings = {
        'LOGSTATS_INTERVAL': 15,
        'EXTENSIONS': {
            'scrapy.extensions.logstats.LogStats': 300
        },
        'DOWNLOAD_DELAY': 0.5,
#         'CONCURRENT_REQUESTS_PER_IP': 3,
#         'CONCURRENT_REQUESTS_PER_DOMAIN': 1,
        'ITEM_PIPELINES': {'spider.MyFilesPipeline': 1},
        'FILES_STORE': 'data',
        'FILES_URLS_FIELD': 'file'
    }

    # start_urls = ['http://www.site.com/links']
    start_urls = ['https://www.hse.ru/edu/courses/page{}.html?words=&full_words=&edu_year=2016&lecturer=&edu_level=&language=&level=1191462%3A133075818&mandatory=&is_dpo=0&filial=22723&xlc=&genelective=0'.format(i) for i in range(1, 2)]



    def parse(self, response):
        item = {}
        item['url'] = response.url
        # logging.debug('yo!')

        for i in response.xpath('//*[@class="b-program"]'):
            item['link'] = i.xpath('.//h2/a/@href').extract_first()
            item['title'] = i.xpath('.//h2/a/text()').extract_first()
            item['year'] = i.xpath('.//div[1]/div[2]/text()').extract_first()

            item['status'] = i.xpath('.//*[@class="statusgenelective"]/text()').extract_first()
            res = i.xpath('.//div[3]/div[position() > 1]')
            path = res[-1].xpath('.//a[@class="link"]/@href').extract_first()
            logging.debug(path)
            if path:
                item['file'] = ['https://www.hse.ru'  + path]
            item['all'] = res.extract()

#             attrs = ['teachers', 'who', 'where', 'language', 'level', 'spec', 'when', 'credits', 'program']
#             for n, attr in enumerate(attrs):
#                 sel = res[n]
#                 print(attr)
#                 item[attr] = sel.extract()

            yield item
